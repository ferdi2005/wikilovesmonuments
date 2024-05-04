class ImportTownsJob < ApplicationJob
  queue_as :default

  def normalize_value(value)
    if value.to_s == ""
      return nil
    elsif value.start_with?("_:")
      return nil
    else
      return value.to_s
    end
  end

  def perform(*args)
    endpoint = "https://query.wikidata.org/sparql"
    sparql = 'SELECT ?item ?itemLabel ?townLabel ?commons ?coords WHERE {
      { ?item wdt:P31 wd:Q747074. }
      UNION
      { ?item wdt:P31 wd:Q954172. }
      UNION
      { ?item wdt:P31 wd:Q1134686. }

      ?item wdt:P131 ?town .
      OPTIONAL {?item wdt:P373 ?commons .}
      OPTIONAL {?item wdt:P625 ?coords. }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "it". }
    }'

    retcount = 0
    begin
      client = SPARQL::Client.new(endpoint, method: :get, headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.5 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
      towns = client.query(sparql)
    rescue => e
      retcount += 1
      if retcount < 5
        retry
      else
        Raven.capture_message('Impossibile eseguire il job di importazione dei comuni per errore nella connessione a SPARQL', level: 'fatal')
        return
      end
    end

    english_sparql = 'SELECT ?item ?itemLabel ?townLabel ?coords WHERE {
      { ?item wdt:P31 wd:Q747074. }
      UNION
      { ?item wdt:P31 wd:Q954172. }
      UNION
      { ?item wdt:P31 wd:Q1134686. }

      ?item wdt:P131 ?town .
      OPTIONAL {?item wdt:P625 ?coords. }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    }'

    retcount = 0
    begin
      english_towns = client.query(english_sparql)
    rescue => e
      retcount += 1
      if retcount < 5
        retry
      else
        Raven.capture_message('Impossibile eseguire il job di importazione dei nomi inglesi per errore nella connessione a SPARQL', level: 'fatal')
        return
      end
    end

    Town.delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Town.table_name)

    towns.each do |town|
      latlongarray = normalize_value(town[:coords]).try(:split, '(').try(:[], 1).try(:split, ')').try(:[], 0).try(:split, ' ')
      unless latlongarray.nil?
        lat = latlongarray[1]
        long = latlongarray[0]
        latitude = BigDecimal(lat)
        longitude = BigDecimal(long)
      else
        latitude = nil
        longitude = nil
      end

      if town[:townLabel].to_s.strip == ""
        disambiguation = nil
        visible_name = town[:itemLabel].to_s.strip
        search_name = town[:itemLabel].to_s.strip
      else
        disambiguation = town[:townLabel].to_s.match(/(città metropolitana di)?(provincia di)?(provincia autonoma di)?(.+)/i)[4].strip
        visible_name = "#{town[:itemLabel].to_s.strip} (#{disambiguation.to_s.strip})"
        search_name = "#{town[:itemLabel].to_s.strip}, #{disambiguation.to_s.strip}"
      end

      item = town[:item].to_s.split('/')[4]

      commons = normalize_value(town[:commons])

      english_town = english_towns.find { |t| t[:item].to_s.split('/')[4] == item && t[:itemLabel] != item }

      if english_town.nil?
        english_name = visible_name
      elsif english_town[:townLabel].to_s.strip.blank?
        english_name = english_town[:itemLabel].to_s.strip
      else
        english_disambiguation = english_town[:townLabel].to_s.strip
        english_name = "#{english_town[:itemLabel].to_s.strip} (#{english_disambiguation.to_s.strip})"
      end

      Town.create(item: item, name: town[:itemLabel].to_s.strip, disambiguation: disambiguation, visible_name: visible_name, search_name: search_name, latitude: latitude, longitude: longitude, english_name: english_name, commons: commons)
    end
  end
end
