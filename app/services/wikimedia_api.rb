# frozen_string_literal: true

require 'httparty'
require 'addressable/uri'
require 'time'

class WikimediaApi
  DEFAULT_USER_AGENT = 'WikiLovesMonumentsItaly MonumentsFinder/1.5 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty Ruby Gem'
  DEFAULT_MAXLAG = 5
  MAX_RETRIES = 5

  @mutex = Mutex.new
  @pause_until = Time.at(0)

  class << self
    attr_reader :mutex

    def pause_until
      @mutex.synchronize { @pause_until }
    end

    def set_pause(seconds)
      @mutex.synchronize do
        new_pause = Time.now + seconds
        @pause_until = new_pause if new_pause > @pause_until
      end
    end

    def wait_if_paused
      delay = 0
      @mutex.synchronize do
        now = Time.now
        delay = @pause_until - now if @pause_until > now
      end
      sleep(delay) if delay > 0
    end

    def reset_pause!
      @mutex.synchronize { @pause_until = Time.at(0) }
    end

    def get(url, query: {}, headers: {}, max_retries: MAX_RETRIES, maxlag: DEFAULT_MAXLAG)
      request(:get, url, query: query, headers: headers, max_retries: max_retries, maxlag: maxlag)
    end

    def request(method, url, query: {}, headers: {}, max_retries: MAX_RETRIES, maxlag: DEFAULT_MAXLAG)
      retries = 0

      merged_headers = {
        'User-Agent' => DEFAULT_USER_AGENT,
        'Accept-Encoding' => 'gzip'
      }.merge(headers)

      merged_query = query.dup
      merged_query[:maxlag] ||= maxlag if maxlag && !merged_query.key?(:maxlag) && !merged_query.key?('maxlag')

      loop do
        wait_if_paused

        begin
          response = HTTParty.send(
            method,
            url,
            query: merged_query,
            headers: merged_headers,
            uri_adapter: Addressable::URI
          )
        rescue StandardError => e
          retries += 1
          if retries <= max_retries
            backoff = calculate_backoff(nil, retries)
            set_pause(backoff)
            Rails.logger.warn("WikimediaApi network error: #{e.message}. Retrying in #{backoff}s (attempt #{retries}/#{max_retries})")
            next
          else
            Rails.logger.error("WikimediaApi network error: #{e.message}. Retries exhausted (#{max_retries})")
            raise e
          end
        end

        # Gestione status HTTP 429 Too Many Requests o 503 Service Unavailable
        if response.code == 429 || response.code == 503
          retries += 1
          if retries <= max_retries
            retry_after_header = response.headers['retry-after']
            backoff = calculate_backoff(retry_after_header, retries)
            set_pause(backoff)
            Rails.logger.warn("WikimediaApi received HTTP #{response.code}. Retrying in #{backoff}s (attempt #{retries}/#{max_retries})")
            next
          else
            Rails.logger.error("WikimediaApi HTTP #{response.code}. Retries exhausted (#{max_retries})")
            return to_hash(response)
          end
        end

        parsed = to_hash(response)

        # Gestione errori specifici MediaWiki restituite nel corpo JSON (maxlag o ratelimited)
        if parsed.is_a?(Hash) && parsed['error']
          error_code = parsed.dig('error', 'code')
          if error_code == 'maxlag' || error_code == 'ratelimited'
            retries += 1
            if retries <= max_retries
              retry_after_header = response.headers['retry-after']
              lag_seconds = parsed.dig('error', 'lag')
              min_delay = lag_seconds.to_f > 0 ? lag_seconds.to_f : 5.0
              backoff = calculate_backoff(retry_after_header, retries, min_delay: min_delay)
              set_pause(backoff)
              Rails.logger.warn("WikimediaApi received #{error_code} error. Retrying in #{backoff}s (attempt #{retries}/#{max_retries})")
              next
            else
              Rails.logger.error("WikimediaApi #{error_code} error. Retries exhausted (#{max_retries})")
              return parsed
            end
          end
        end

        return parsed
      end
    end

    def calculate_backoff(retry_after_header, attempt, min_delay: 2.0)
      if retry_after_header.present?
        parsed_delay = parse_retry_after(retry_after_header)
        return [parsed_delay, min_delay].max if parsed_delay
      end

      delay = (2**attempt) + rand(0.5..1.5)
      [delay, min_delay].max.round(1)
    end

    def parse_retry_after(header_value)
      val = header_value.to_s.strip
      return nil if val.empty?

      # Formato numerico in secondi (es. "5" o "120")
      if val =~ /\A\d+(\.\d+)?\z/
        return val.to_f
      end

      # Formato data HTTP (es. "Wed, 21 Oct 2026 07:28:00 GMT")
      begin
        parsed_time = Time.httpdate(val)
        diff = parsed_time - Time.now
        return diff > 0 ? diff.ceil.to_f : 1.0
      rescue ArgumentError
        begin
          parsed_time = Time.parse(val)
          diff = parsed_time - Time.now
          return diff > 0 ? diff.ceil.to_f : 1.0
        rescue ArgumentError
          nil
        end
      end
    end

    private

    def to_hash(response)
      parsed = response.parsed_response
      return parsed if parsed.is_a?(Hash)

      if response.body.is_a?(String) && !response.body.empty?
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          {}
        end
      else
        {}
      end
    end
  end
end
