# frozen_string_literal: true

class CreateUrlJob < ApplicationJob
  queue_as :default

  def createurl(monument, fallback_commons: nil)
    @lakecomo ||= []
    urls = UploadUrlBuilder.build_urls(
      monument,
      lakecomo_items: @lakecomo,
      fallback_commons: fallback_commons
    )
    return if urls[:uploadurl].blank?

    monument.update!(uploadurl: urls[:uploadurl], nonwlmuploadurl: urls[:nonwlmuploadurl])
  end

  def perform(*_args)
    @lakecomo = fetch_lakecomo_items
    town_commons = Town.where.not(commons: [nil, ""]).pluck(:item, :commons).to_h

    Monument.find_each do |monument|
      createurl(monument, fallback_commons: town_commons[monument.city_item])
    end
  end

  private

  def fetch_lakecomo_items
    sparql = <<~SPARQL
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
      PREFIX wd: <http://www.wikidata.org/entity/>
      PREFIX wdt: <http://www.wikidata.org/prop/direct/>
      PREFIX p: <http://www.wikidata.org/prop/>
      PREFIX pq: <http://www.wikidata.org/prop/qualifier/>

      SELECT DISTINCT ?item
      WHERE {
        VALUES ?lakecomo { wd:Q16161 wd:Q16199 }
        ?item wdt:P2186 ?wlmid ;
              wdt:P17 wd:Q38 ;
              wdt:P131* ?lakecomo .
        MINUS {
          ?item p:P2186 [ pq:P582 ?end ] .
          FILTER (?end <= "#{Date.today.year}-09-01T00:00:00+00:00"^^xsd:dateTime)
        }
      }
    SPARQL

    rows = WikidataSparqlClient.query(sparql)
    rows.filter_map do |row|
      item_code = row.dig("item", "value").to_s.split("/")[4]
      item_code unless item_code.blank? || UploadUrlBuilder::BANNED_COMO.include?(item_code)
    end
  rescue StandardError => e
    Rails.logger.warn("[CreateUrlJob] Impossibile recuperare gli item Lake Como: #{e.message}")
    []
  end
end
