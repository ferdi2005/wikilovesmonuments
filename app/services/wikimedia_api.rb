# frozen_string_literal: true

require 'httparty'
require 'addressable/uri'
require 'time'

class WikimediaApi
  DEFAULT_USER_AGENT = 'WikiLovesMonumentsItaly MonumentsFinder/1.5 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty Ruby Gem'
  DEFAULT_MAXLAG = 5
  MAX_RETRIES = 5
  # Su Wikimedia Toolforge non si applica il limite per client esterni di 200 richieste/minuto
  MIN_REQUEST_INTERVAL = (ENV["TOOLFORGE"].to_s.downcase == "true") ? 0.0 : 0.35

  @mutex = Mutex.new
  @pause_until = Time.at(0)
  @last_request_at = nil

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

    def enforce_rate_limit
      return if MIN_REQUEST_INTERVAL <= 0.0

      delay = 0
      @mutex.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if @last_request_at
          elapsed = now - @last_request_at
          delay = MIN_REQUEST_INTERVAL - elapsed if elapsed < MIN_REQUEST_INTERVAL
        end
        @last_request_at = now + (delay > 0 ? delay : 0)
      end
      sleep(delay) if delay > 0
    end

    def reset_pause!
      @mutex.synchronize do
        @pause_until = Time.at(0)
        @last_request_at = nil
      end
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
        enforce_rate_limit
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
            msg = "[WikimediaApi] Errore di rete: #{e.message}. Attesa di #{backoff}s prima del tentativo #{retries}/#{max_retries}..."
            puts msg
            Rails.logger.warn(msg)
            sleep(backoff)
            next
          else
            msg = "[WikimediaApi] Errore di rete: #{e.message}. Tentativi esauriti (#{max_retries})"
            puts msg
            Rails.logger.error(msg)
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
            msg = "[WikimediaApi] HTTP #{response.code} ricevuto (Retry-After: #{retry_after_header.inspect}). Attesa di #{backoff}s prima del tentativo #{retries}/#{max_retries}..."
            puts msg
            Rails.logger.warn(msg)
            sleep(backoff)
            next
          else
            msg = "[WikimediaApi] HTTP #{response.code}. Tentativi esauriti (#{max_retries})"
            puts msg
            Rails.logger.error(msg)
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
              msg = "[WikimediaApi] MediaWiki ha restituito #{error_code}. Attesa di #{backoff}s prima del tentativo #{retries}/#{max_retries}..."
              puts msg
              Rails.logger.warn(msg)
              sleep(backoff)
              next
            else
              msg = "[WikimediaApi] Errore #{error_code} MediaWiki. Tentativi esauriti (#{max_retries})"
              puts msg
              Rails.logger.error(msg)
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
        if parsed_delay
          # Aggiunta di un buffer di 1.5 secondi per garantire il superamento della finestra sul server
          return [parsed_delay + 1.5, min_delay].max.round(1)
        end
      end

      delay = (2**attempt) + rand(0.5..1.5)
      [delay, min_delay].max.round(1)
    end

    def parse_retry_after(header_value)
      val = Array(header_value).flatten.compact.first.to_s.strip
      return nil if val.empty?

      # Formato numerico in secondi (es. "11" o "11.5")
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
