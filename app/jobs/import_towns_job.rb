class ImportTownsJob < ApplicationJob
  queue_as :default

  def perform(*args)

    Town.destroy_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Town.table_name)

    endpoint = "https://query.wikidata.org/sparql"
    sparql = 'SELECT ?item ?itemLabel WHERE {
      { ?item wdt:P31 wd:Q747074. }
      UNION
      { ?item wdt:P31 wd:Q954172. }
      UNION
      { ?item wdt:P31 wd:Q1134686. }
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
    
    towns.each do |town|
      Town.create(name: town[:itemLabel])
    end
  end
end
