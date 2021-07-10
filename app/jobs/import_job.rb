# frozen_string_literal: true

class ImportJob < ApplicationJob
  queue_as :default

  def perform
    Monument.delete_all
    # Resetta gli id in modo che partano da 1
    ActiveRecord::Base.connection.reset_pk_sequence!(Monument.table_name)
    endpoint = 'https://query.wikidata.org/sparql'
    # Query di Lorenzo Losa
    sparql = '
    SELECT DISTINCT ?item ?itemLabel ?itemDescription ?coords ?wlmid ?image ?sitelink ?commons ?regioneLabel ?enddate ?unitLabel ?address ?instanceof
    WHERE {
 ?item p:P2186 ?wlmst .
  ?wlmst ps:P2186 ?wlmid .
  
      ?item wdt:P17 wd:Q38 . 
      ?item wdt:P131 ?unit .

      MINUS {?item wdt:P31 wd:Q747074.}
      MINUS {?item wdt:P31 wd:Q954172.}
    
    OPTIONAL {?item wdt:P31 ?instanceof }
    OPTIONAL {?item wdt:P625 ?coords. }
    OPTIONAL { ?wlmst pqv:P582 [ wikibase:timeValue ?enddate ] .}
    OPTIONAL { ?item wdt:P373 ?commons. }
    OPTIONAL { ?item wdt:P18 ?image. }
    OPTIONAL { ?item wdt:P6375 ?address.}
    OPTIONAL {?sitelink schema:isPartOf <https://it.wikipedia.org/>;schema:about ?item. }
    VALUES ?typeRegion { wd:Q16110 wd:Q1710033 }.

  ?item wdt:P131* ?regione.
  ?regione wdt:P31 ?typeRegion.



  # esclude i monumenti che hanno una data di termine precedente alla data di inizio del concorso
  MINUS {
    ?wlmst pqv:P582 [ wikibase:timeValue ?end ; wikibase:timePrecision ?eprec ] .
    FILTER (
      ( ?eprec >  9 && ?end < "2020-09-01T00:00:00+00:00"^^xsd:dateTime ) ||
      ( ?eprec < 10 && ?end < "2020-01-01T00:00:00+00:00"^^xsd:dateTime )
    )
  }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "it" }
      }'

    retcount = 0
    begin
      client = SPARQL::Client.new(endpoint, method: :get, headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
      monuments = client.query(sparql)
    rescue StandardError
      retcount += 1
      if retcount < 5
        retry
      else
        @stop = true
        Raven.capture_message('Impossibile eseguire il job di importazione per errore nella connessione a SPARQL', level: 'fatal')
      end
    end

    unless @stop == true
      monuments.each do |monument|
        @mon = Monument.new
          @mon.item = monument[:item].to_s.split('/')[4]

          @mon.wlmid = monument[:wlmid].to_s
          
          latlongarray = monument[:coords].to_s.split('(')[1].split(')')[0].split(' ')
          lat = latlongarray[1]
          long = latlongarray[0]
          @mon.latitude = BigDecimal(lat)
          @mon.longitude = BigDecimal(long)

          @mon.itemlabel = monument[:itemLabel].to_s
          
          @mon.image = monument[:image].to_s.split('Special:FilePath/')[1]

          @mon.commons = monument[:commons].to_s

          @mon.itemdescription = monument[:itemDescription].to_s

          @mon.wikipedia = monument[:sitelink].to_s

          @mon.regione = monument[:regioneLabel].to_s

          @mon.enddate = monument[:enddate].to_s

          @mon.city = monument[:unitLabel].to_s

          @mon.address = monument[:address].to_s

          @mon.tree = true if monument[:instanceof].to_s == "http://www.wikidata.org/entity/Q811534"
          
        if @mon.latitude.blank? || @mon.longitude.blank?
          @mon.hidden = true
        end

        if @mon.enddate.nil? || @mon.enddate > Date.today
          @mon.save
        end
      end
      LookupJob.perform_later
      CheckDuplicatesJob.perform_later
    end
  end
end
