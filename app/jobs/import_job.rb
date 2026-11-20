# frozen_string_literal: true

require "set"

class ImportJob < ApplicationJob
  queue_as :default

  REGIONI = {
    "Q1284" => "Abruzzo",
    "Q1452" => "Basilicata",
    "Q1458" => "Calabria",
    "Q1438" => "Campania",
    "Q1263" => "Emilia-Romagna",
    "Q1250" => "Friuli-Venezia Giulia",
    "Q1282" => "Lazio",
    "Q1256" => "Liguria",
    "Q1210" => "Lombardia",
    "Q1279" => "Marche",
    "Q1443" => "Molise",
    "Q1216" => "Piemonte",
    "Q1447" => "Puglia",
    "Q1462" => "Sardegna",
    "Q1460" => "Sicilia",
    "Q1273" => "Toscana",
    "Q1237" => "Trentino-Alto Adige",
    "Q1280" => "Umbria",
    "Q1222" => "Valle d'Aosta",
    "Q1243" => "Veneto"
  }.freeze

  def normalize_value(value)
    return nil if value.to_s.empty? || value.start_with?("_:")

    value.to_s
  end

  def perform
    sparql = <<~SPARQL
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
      PREFIX wikibase: <http://wikiba.se/ontology#>
      PREFIX schema: <http://schema.org/>
      PREFIX wd: <http://www.wikidata.org/entity/>
      PREFIX wdt: <http://www.wikidata.org/prop/direct/>
      PREFIX p: <http://www.wikidata.org/prop/>
      PREFIX ps: <http://www.wikidata.org/prop/statement/>
      PREFIX pq: <http://www.wikidata.org/prop/qualifier/>
      PREFIX pqv: <http://www.wikidata.org/prop/qualifier/value/>

      SELECT DISTINCT ?item ?itemLabel ?itemDescription ?coords ?wlmid ?image ?sitelink ?commons ?regione ?enddate ?unit ?unitLabel ?unitCommons ?address ?approvedby ?religiousSponsor ?year ?instanceof
      WHERE {
        ?item p:P2186 ?wlmst .
        ?wlmst ps:P2186 ?wlmid .

        OPTIONAL { ?wlmst pq:P790 ?approvedby . }
        OPTIONAL { ?wlmst pq:P8001 ?religiousSponsor . }

        ?item wdt:P17 wd:Q38 .
        ?item wdt:P131 ?unit .

        MINUS { ?item wdt:P31 wd:Q747074 . }
        MINUS { ?item wdt:P31 wd:Q954172 . }
        MINUS { ?item wdt:P31 wd:Q1549591 . }

        OPTIONAL { ?item wdt:P31 ?instanceof . }
        OPTIONAL { ?item wdt:P625 ?coords . }
        OPTIONAL { ?wlmst pqv:P582 [ wikibase:timeValue ?enddate ] . }
        OPTIONAL { ?wlmst pqv:P585 [ wikibase:timeValue ?year ] . }
        OPTIONAL { ?item wdt:P373 ?commons . }
        OPTIONAL { ?item wdt:P18 ?image . }
        OPTIONAL { ?item wdt:P6375 ?address . }
        OPTIONAL { ?sitelink schema:isPartOf <https://it.wikipedia.org/> ; schema:about ?item . }
        VALUES ?typeRegion { wd:Q16110 wd:Q1710033 } .

        ?item wdt:P131* ?regione .
        ?regione wdt:P31 ?typeRegion .

        OPTIONAL { ?unit wdt:P373 ?unitCommons . }
        OPTIONAL { ?unit rdfs:label ?unitLabelIt FILTER (LANG(?unitLabelIt) = 'it') }
        OPTIONAL { ?unit rdfs:label ?unitLabelMul FILTER (LANG(?unitLabelMul) = 'mul') }
        BIND(COALESCE(?unitLabelIt, ?unitLabelMul) AS ?unitLabel)

        OPTIONAL { ?item rdfs:label ?itemLabelIt FILTER (LANG(?itemLabelIt) = 'it') }
        OPTIONAL { ?item rdfs:label ?itemLabelMul FILTER (LANG(?itemLabelMul) = 'mul') }
        BIND(COALESCE(?itemLabelIt, ?itemLabelMul) AS ?itemLabel)
        FILTER (BOUND(?itemLabel))

        OPTIONAL { ?item schema:description ?itemDescription FILTER (LANG(?itemDescription) = 'it') }
      }
    SPARQL

    begin
      monuments = WikidataSparqlClient.query(sparql)
    rescue StandardError => e
      Raven.capture_message("Impossibile eseguire il job di importazione per errore nella connessione a SPARQL: #{e}", level: "fatal")
      return
    end

    lakecomo_set = fetch_lakecomo_items
    monuments_to_be_saved = {}
    now = DateTime.now

    monuments.uniq.each do |monument|
      item_uri = normalize_value(monument.dig("item", "value"))
      item = item_uri&.split("/")&.dig(4)
      wlmid = normalize_value(monument.dig("wlmid", "value"))
      next if item.blank? || wlmid.blank?

      mon = {}
      mon[:item] = item
      mon[:wlmid] = wlmid

      latlongarray = normalize_value(monument.dig("coords", "value"))&.split("(")&.dig(1)&.split(")")&.dig(0)&.split(" ")
      if latlongarray.present? && latlongarray.length >= 2
        mon[:latitude] = BigDecimal(latlongarray[1])
        mon[:longitude] = BigDecimal(latlongarray[0])
      else
        mon[:latitude] = nil
        mon[:longitude] = nil
      end

      mon[:itemlabel] = normalize_value(monument.dig("itemLabel", "value"))
      mon[:image] = normalize_value(monument.dig("image", "value"))&.split("Special:FilePath/")&.dig(1)
      mon[:commons] = normalize_value(monument.dig("commons", "value"))
      mon[:itemdescription] = normalize_value(monument.dig("itemDescription", "value"))
      mon[:wikipedia] = normalize_value(monument.dig("sitelink", "value"))

      regione_qid = normalize_value(monument.dig("regione", "value"))&.split("/")&.dig(4)
      mon[:regione] = REGIONI[regione_qid]

      mon[:enddate] = normalize_value(monument.dig("enddate", "value"))
      mon[:year] = normalize_value(monument.dig("year", "value"))
      mon[:city_item] = normalize_value(monument.dig("unit", "value"))&.split("/")&.dig(4)
      mon[:city] = normalize_value(monument.dig("unitLabel", "value"))
      mon[:address] = normalize_value(monument.dig("address", "value"))
      mon[:allphotos] = %(https://commons.wikimedia.org/w/index.php?search="#{wlmid}")

      mon[:tree] = normalize_value(monument.dig("instanceof", "value")) == "http://www.wikidata.org/entity/Q811534"
      mon[:is_castle] = normalize_value(monument.dig("approvedby", "value")) == "http://www.wikidata.org/entity/Q85864317"
      mon[:_religious] = normalize_value(monument.dig("religiousSponsor", "value")).present?
      mon[:_unit_commons] = normalize_value(monument.dig("unitCommons", "value"))

      mon[:hidden] = mon[:latitude].blank? || mon[:longitude].blank?

      unless mon[:year].nil?
        begin
          mon[:noupload] = DateTime.parse(mon[:year])&.year != Date.today.year
        rescue Date::Error
          mon[:noupload] = false
        end
      end

      unless mon[:enddate].nil?
        mon[:noupload] = mon[:enddate].to_datetime < Date.today
      end

      mon[:noupload] = false if mon[:noupload].nil?
      mon[:created_at] = now
      mon[:updated_at] = now

      if (existing = monuments_to_be_saved[mon[:item]])
        mon[:tree] ||= existing[:tree]
        mon[:is_castle] ||= existing[:is_castle]
        mon[:_religious] ||= existing[:_religious]
        mon[:_unit_commons] ||= existing[:_unit_commons]
        if mon[:latitude].blank? && existing[:latitude].present?
          mon[:latitude] = existing[:latitude]
          mon[:longitude] = existing[:longitude]
          mon[:hidden] = false
        end
        mon[:image] ||= existing[:image]
        mon[:commons] ||= existing[:commons]
      end

      monuments_to_be_saved[mon[:item]] = mon
    end

    wlmid_counts = monuments_to_be_saved.values.each_with_object(Hash.new(0)) do |m, counts|
      counts[m[:wlmid]] += 1 if m[:wlmid].present?
    end

    monuments_to_be_saved.each_value do |mon|
      mon[:duplicate] = wlmid_counts[mon[:wlmid]] > 1
      unit_commons = mon.delete(:_unit_commons)
      religious = mon.delete(:_religious)
      urls = UploadUrlBuilder.build_urls(
        mon,
        lakecomo_items: lakecomo_set,
        fallback_commons: unit_commons,
        religious: religious
      )
      mon[:uploadurl] = urls[:uploadurl]
      mon[:nonwlmuploadurl] = urls[:nonwlmuploadurl]
    end

    records_to_upsert = monuments_to_be_saved.values

    records_to_upsert.each_slice(5000) do |slice|
      if Monument.connection.supports_insert_conflict_target?
        Monument.upsert_all(slice, unique_by: :item)
      else
        Monument.upsert_all(slice)
      end
    end

    items_to_be_deleted = Monument.pluck(:item).uniq - monuments_to_be_saved.keys
    Monument.where(item: items_to_be_deleted).in_batches.destroy_all if items_to_be_deleted.any?

    CacheWarmJob.perform_later
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
    items = Set.new
    rows.each do |row|
      item_code = normalize_value(row.dig("item", "value"))&.split("/")&.dig(4)
      items.add(item_code) if item_code.present? && !UploadUrlBuilder::BANNED_COMO.include?(item_code)
    end
    items
  rescue StandardError => e
    Rails.logger.warn("[ImportJob] Impossibile recuperare gli item Lake Como: #{e.message}")
    Set.new
  end
end
