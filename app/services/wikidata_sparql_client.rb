# frozen_string_literal: true

require "httparty"
require "json"

# Client SPARQL centralizzato compatibile con QLever e WDQS.
# Tutte le query devono evitare estensioni proprietarie (es. SERVICE wikibase:label)
# e dichiarare esplicitamente i PREFIX necessari.
class WikidataSparqlClient
  QLEVER_ENDPOINT = "https://qlever.dev/api/wikidata".freeze
  WDQS_ENDPOINT = "https://query.wikidata.org/sparql".freeze
  USER_AGENT = "WikiLovesMonumentsItaly MonumentsFinder/2.0 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty".freeze

  class << self
    def endpoints
      custom = ENV["WIKIDATA_SPARQL_ENDPOINT"].to_s.strip
      if custom.empty?
        [QLEVER_ENDPOINT, WDQS_ENDPOINT]
      else
        [custom, QLEVER_ENDPOINT, WDQS_ENDPOINT].uniq
      end
    end

    def query(sparql, max_retries: 5)
      endpoints_list = endpoints
      attempt = 0

      begin
        endpoint = endpoints_list[attempt % endpoints_list.length]
        response = HTTParty.post(
          endpoint,
          body: { query: sparql },
          headers: {
            "Accept" => "application/sparql-results+json",
            "User-Agent" => USER_AGENT
          },
          format: :json,
          timeout: 120
        )

        raise "Risposta non valida da SPARQL #{endpoint} (status #{response.code})" unless response.success?

        parsed = parse_response(response)
        bindings = parsed&.dig("results", "bindings")
        raise "Risultati SPARQL vuoti o non validi da #{endpoint}" unless bindings.is_a?(Array)

        bindings
      rescue StandardError => e
        attempt += 1
        if attempt < max_retries
          retry
        else
          raise e
        end
      end
    end

    private

    def parse_response(response)
      parsed = response.parsed_response
      return parsed if parsed.is_a?(Hash)

      if response.body.is_a?(String) && !response.body.empty?
        JSON.parse(response.body)
      end
    rescue JSON::ParserError
      nil
    end
  end
end
