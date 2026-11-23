# frozen_string_literal: true

class ImportTownsJob < ApplicationJob
  queue_as :default

  def normalize_value(value)
    return nil if value.to_s.empty? || value.start_with?("_:")

    value.to_s
  end

  def perform(*_args)
    sparql = <<~SPARQL
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX wd: <http://www.wikidata.org/entity/>
      PREFIX wdt: <http://www.wikidata.org/prop/direct/>

      SELECT ?item ?itemLabelIt ?itemLabelMul ?townLabelIt ?itemLabelEn ?townLabelEn ?commons ?coords ?population WHERE {
        VALUES ?type { wd:Q747074 wd:Q954172 wd:Q1134686 }
        ?item wdt:P31 ?type .
        ?item wdt:P131 ?town .
        OPTIONAL { ?item wdt:P373 ?commons . }
        OPTIONAL { ?item wdt:P625 ?coords . }
        OPTIONAL { ?item wdt:P1082 ?population . }
        OPTIONAL { ?item rdfs:label ?itemLabelIt FILTER(LANG(?itemLabelIt) = "it") }
        OPTIONAL { ?item rdfs:label ?itemLabelMul FILTER(LANG(?itemLabelMul) = "mul") }
        OPTIONAL { ?town rdfs:label ?townLabelIt FILTER(LANG(?townLabelIt) = "it") }
        OPTIONAL { ?item rdfs:label ?itemLabelEn FILTER(LANG(?itemLabelEn) = "en") }
        OPTIONAL { ?town rdfs:label ?townLabelEn FILTER(LANG(?townLabelEn) = "en") }
      }
    SPARQL

    begin
      towns = WikidataSparqlClient.query(sparql)
    rescue StandardError => e
      Raven.capture_message("Impossibile eseguire il job di importazione dei comuni per errore nella connessione a SPARQL: #{e}", level: "fatal")
      return
    end

    now = Time.current
    records_by_key = {}

    towns.each do |town|
      item = normalize_value(town.dig("item", "value"))&.split("/")&.dig(4)
      next if item.blank?

      name_it = normalize_value(town.dig("itemLabelIt", "value")) || normalize_value(town.dig("itemLabelMul", "value"))
      next if name_it.blank?

      name_it = name_it.strip
      town_label_it = normalize_value(town.dig("townLabelIt", "value")).to_s.strip

      latlongarray = normalize_value(town.dig("coords", "value"))&.split("(")&.dig(1)&.split(")")&.dig(0)&.split(" ")
      if latlongarray.present? && latlongarray.length >= 2
        latitude = BigDecimal(latlongarray[1])
        longitude = BigDecimal(latlongarray[0])
      else
        latitude = nil
        longitude = nil
      end

      if town_label_it.empty?
        disambiguation = nil
        visible_name = name_it
        search_name = name_it
      else
        match = town_label_it.match(/(città metropolitana di)?(provincia di)?(provincia autonoma di)?(.+)/i)
        disambiguation = match ? match[4].strip : town_label_it
        visible_name = "#{name_it} (#{disambiguation})"
        search_name = "#{name_it}, #{disambiguation}"
      end

      commons = normalize_value(town.dig("commons", "value"))
      raw_pop = normalize_value(town.dig("population", "value"))
      population = raw_pop&.match?(/\A\d+(\.\d+)?\z/) ? raw_pop.to_i : nil

      name_en = normalize_value(town.dig("itemLabelEn", "value"))&.strip
      town_label_en = normalize_value(town.dig("townLabelEn", "value"))&.strip
      english_name = if name_en.blank?
                       visible_name
                     elsif town_label_en.blank?
                       name_en
                     else
                       "#{name_en} (#{town_label_en})"
                     end

      dedup_key = [name_it, disambiguation]
      existing = records_by_key[dedup_key]
      if existing
        existing[:commons] ||= commons
        existing[:latitude] ||= latitude
        existing[:longitude] ||= longitude
        existing[:population] = [existing[:population], population].compact.max
        next
      end

      records_by_key[dedup_key] = {
        item: item,
        name: name_it,
        disambiguation: disambiguation,
        visible_name: visible_name,
        search_name: search_name,
        latitude: latitude,
        longitude: longitude,
        english_name: english_name,
        commons: commons,
        population: population,
        created_at: now,
        updated_at: now
      }
    end

    records = records_by_key.values
    return if records.empty?

    Town.transaction do
      Town.delete_all
      ActiveRecord::Base.connection.reset_pk_sequence!(Town.table_name)
      records.each_slice(2000) do |slice|
        Town.insert_all(slice)
      end
    end
  end
end
