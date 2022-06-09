class ImportJob < ApplicationJob
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

  def perform
    endpoint = 'https://query.wikidata.org/sparql'
    # Query di Lorenzo Losa
    sparql = 'SELECT DISTINCT ?item ?itemLabel ?itemDescription ?coords ?wlmid ?image ?sitelink ?commons ?regioneLabel ?enddate ?unit ?unitLabel ?address ?approvedby ?year
    WHERE {
      ?item p:P2186 ?wlmst .
      ?wlmst ps:P2186 ?wlmid .
      OPTIONAL { ?wlmst pq:P790 ?approvedby . }

      ?item wdt:P17 wd:Q38 . 
      ?item wdt:P131 ?unit .
      
      MINUS {?item wdt:P31 wd:Q747074.}
      MINUS {?item wdt:P31 wd:Q954172.}
    
      OPTIONAL {?item wdt:P625 ?coords. }
      OPTIONAL { ?wlmst pqv:P582 [ wikibase:timeValue ?enddate ] .}
      OPTIONAL { ?wlmst pqv:P585 [ wikibase:timeValue ?year ] .}
      OPTIONAL { ?item wdt:P373 ?commons. }
      OPTIONAL { ?item wdt:P18 ?image. }
      OPTIONAL { ?item wdt:P6375 ?address.}
      OPTIONAL {?sitelink schema:isPartOf <https://it.wikipedia.org/>;schema:about ?item. }
      VALUES ?typeRegion { wd:Q16110 wd:Q1710033 }.

      ?item wdt:P131* ?regione.
      ?regione wdt:P31 ?typeRegion.

      # esclude i monumenti che hanno una data di inizio successiva al termine del concorso
      MINUS {
        ?wlmst pqv:P580 [ wikibase:timeValue ?start ; wikibase:timePrecision ?sprec ] .
        FILTER (
          # precisione 9 è anno
          ( ?sprec >  9 && ?start >= "' + Date.today.year.to_s + '-10-01T00:00:00+00:00"^^xsd:dateTime ) ||
          ( ?sprec < 10 && ?start >= "' + (Date.today.year + 1).to_s + '-01-01T00:00:00+00:00"^^xsd:dateTime )
        )
      }
      
      SERVICE wikibase:label { bd:serviceParam wikibase:language "it" }
      }'

    retcount = 0
    begin
      client = SPARQL::Client.new(endpoint, method: :get, headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
      monuments = client.query(sparql)
    rescue => e
      retcount += 1
      if retcount < 5
        retry
      else
        Raven.capture_message("Impossibile eseguire il job di importazione per errore nella connessione a SPARQL: #{e}", level: 'fatal')
        return
      end
    end

    monuments_to_be_saved = []
    monuments.uniq.each do |monument|
      mon = {}

      mon[:item] = normalize_value(monument[:item]).split('/')[4]

      mon[:wlmid] = normalize_value(monument[:wlmid])

      latlongarray = normalize_value(monument[:coords]).try(:split, '(').try(:[], 1).try(:split, ')').try(:[], 0).try(:split, ' ')
      unless latlongarray.nil?
        lat = latlongarray[1]
        long = latlongarray[0]
        mon[:latitude] = BigDecimal(lat)
        mon[:longitude] = BigDecimal(long)
      else
        mon[:latitude] = nil
        mon[:longitude] = nil
      end

      mon[:itemlabel] = normalize_value(monument[:itemLabel])

      mon[:image] = normalize_value(monument[:image]).try(:split, 'Special:FilePath/').try(:[], 1)

      mon[:commons] = normalize_value(monument[:commons])

      mon[:itemdescription] = normalize_value(monument[:itemDescription])

      mon[:wikipedia] = normalize_value(monument[:sitelink])

      mon[:regione] = normalize_value(monument[:regioneLabel])

      mon[:enddate] = normalize_value(monument[:enddate])

      mon[:year] = normalize_value(monument[:year])

      mon[:city_item] = normalize_value(monument[:unit]).split('/')[4]

      mon[:city] = normalize_value(monument[:unitLabel])

      mon[:address] = normalize_value(monument[:address])

      mon[:allphotos] = "https://commons.wikimedia.org/w/index.php?search=#{CGI.escape('"')}#{normalize_value(monument[:wlmid])}#{CGI.escape('"')}"

      if normalize_value(monument[:instanceof]) == "http://www.wikidata.org/entity/Q811534"
        mon[:tree] = true
      else
        mon[:tree] = false
      end

      if normalize_value(monument[:approvedby]) == "http://www.wikidata.org/entity/Q85864317"
        mon[:is_castle] = true
      else
        mon[:is_castle] = false
      end


      if mon[:latitude].blank? || mon[:longitude].blank?
        mon[:hidden] = true
      else
        mon[:hidden] = false
      end

      if !mon[:year].try(:year).nil? && mon[:year].try(:year) != Date.today.year
        mon[:noupload] = true
      else
        mon[:noupload] = false
      end

      unless mon[:enddate].nil?
        if mon[:enddate].to_datetime < Date.today
          mon[:noupload] = true
        else 
          mon[:noupload] = false
        end
      end


      monuments_to_be_saved.reject! { |i| i[:item] == mon[:item] } # Elimina duplicati (salvando dunque l'ultimo che arriva) derivanti da dati "sporchi"
      monuments_to_be_saved.push(mon) unless mon[:wlmid].nil?
    end

    monuments_to_be_saved.uniq!

    monuments_to_be_saved.map! { |mon| mon.merge({created_at: DateTime.now, updated_at: DateTime.now})}

    Monument.upsert_all(monuments_to_be_saved, unique_by: :item)

    # Cancella monumenti che non vengono più restituiti dalla query
    items_to_be_deleted = Monument.pluck(:item).uniq - monuments_to_be_saved.pluck(:item).uniq

    items_to_be_deleted.each { |item| Monument.find_by(item: item).destroy }
  end
end