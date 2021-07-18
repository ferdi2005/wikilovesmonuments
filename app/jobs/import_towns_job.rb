class ImportTownsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    endpoint = "https://query.wikidata.org/sparql"
    sparql = 'SELECT ?item ?itemLabel ?townLabel WHERE {
      { ?item wdt:P31 wd:Q747074. }
      UNION
      { ?item wdt:P31 wd:Q954172. }
      UNION
      { ?item wdt:P31 wd:Q1134686. }

      ?item wdt:P131 ?town .
      SERVICE wikibase:label { bd:serviceParam wikibase:language "it". }
    }'
    
    retcount = 0
    begin
      client = SPARQL::Client.new(endpoint, method: :get, headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
      towns = client.query(sparql)
    rescue => e
      retcount += 1
      if retcount < 5
        retry
      else
        @stop = true
        Raven.capture_message('Impossibile eseguire il job di importazione dei comuni per errore nella connessione a SPARQL', level: 'fatal')
      end
    end

    Town.delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Town.table_name)
    
    towns.each do |town|
      if town[:townLabel].to_s == ""
        disambiguation = nil
        visible_name = town[:itemLabel].to_s.strip
        search_name = town[:itemLabel].to_s.strip
      else
        disambiguation = town[:townLabel].to_s.match(/(città metropolitana di)?(provincia di)?(provincia autonoma di)?(.+)/i)[4].strip
        visible_name = "#{town[:itemLabel].to_s.strip} (#{disambiguation.to_s.strip})"
        search_name = "#{town[:itemLabel].to_s.strip}, #{disambiguation.to_s.strip}"
        item = town[:item].to_s.split('/')[4]
      end

      Town.create(item: item, name: town[:itemLabel].to_s.strip, disambiguation: disambiguation, visible_name: visible_name, search_name: search_name)
    end
  end
end
