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
    # Hash che associa i QID delle regioni italiane ai nomi delle regioni
      regioni = {
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
      }

    endpoint = 'https://qlever.cs.uni-freiburg.de/api/wikidata'
    # Query di Lorenzo Losa
    sparql = <<QUERY
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
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT DISTINCT ?item ?itemLabel ?itemDescription ?coords ?wlmid ?image ?sitelink ?commons ?regione ?enddate ?unit ?unitLabel ?address ?approvedby ?year ?instanceof
    WHERE {
      ?item p:P2186 ?wlmst .
      ?wlmst ps:P2186 ?wlmid .

      OPTIONAL { ?wlmst pq:P790 ?approvedby . }

      ?item wdt:P17 wd:Q38 .
      ?item wdt:P131 ?unit .


      MINUS {?item wdt:P31 wd:Q747074.}
      MINUS {?item wdt:P31 wd:Q954172.}
      MINUS {?item wdt:P31 wd:Q1549591.}

      OPTIONAL {?item wdt:P31 ?instanceof }
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

           ?unit rdfs:label ?unitLabel FILTER (LANG(?unitLabel) = "it")
		   ?item rdfs:label ?itemLabel FILTER (LANG(?itemLabel) = "it")
		  OPTIONAL { ?item schema:description ?itemDescription FILTER (LANG(?itemDescription) = "it") }
      }
QUERY

    retcount = 0
    begin
      monuments_request = HTTParty.post("https://qlever.cs.uni-freiburg.de/api/wikidata", body: { query: sparql })
      monuments = monuments_request["results"]["bindings"]
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

      mon[:item] = normalize_value(monument["item"].try(:[], "value")).split('/')[4]

      mon[:wlmid] = normalize_value(monument["wlmid"].try(:[], "value"))

      latlongarray = normalize_value(monument["coords"].try(:[], "value")).try(:split, '(').try(:[], 1).try(:split, ')').try(:[], 0).try(:split, ' ')
      unless latlongarray.nil?
        lat = latlongarray[1]
        long = latlongarray[0]
        mon[:latitude] = BigDecimal(lat)
        mon[:longitude] = BigDecimal(long)
      else
        mon[:latitude] = nil
        mon[:longitude] = nil
      end

      mon[:itemlabel] = normalize_value(monument["itemLabel"].try(:[], "value"))

      mon[:image] = normalize_value(monument["image"].try(:[], "value")).try(:split, 'Special:FilePath/').try(:[], 1)

      mon[:commons] = normalize_value(monument["commons"].try(:[], "value"))

      mon[:itemdescription] = normalize_value(monument["itemDescription"].try(:[], "value"))

      mon[:wikipedia] = normalize_value(monument["sitelink"].try(:[], "value"))

      mon[:regione] = regioni[normalize_value(monument["regione"].try(:[], "value")).split('/')[4]]

      mon[:enddate] = normalize_value(monument["enddate"].try(:[], "value"))

      mon[:year] = normalize_value(monument["year"].try(:[], "value"))

      mon[:city_item] = normalize_value(monument["unit"].try(:[], "value")).split('/')[4]

      mon[:city] = normalize_value(monument["unitLabel"].try(:[], "value"))

      mon[:address] = normalize_value(monument["address"].try(:[], "value"))

      mon[:allphotos] = 'https://commons.wikimedia.org/w/index.php?search="' + normalize_value(monument["wlmid"].try(:[], "value")) + + '"'

      if normalize_value(monument["instanceof"].try(:[], "value")) == "http://www.wikidata.org/entity/Q811534"
        mon[:tree] = true
      else
        mon[:tree] = false
      end

      if normalize_value(monument["approvedby"].try(:[], "value")) == "http://www.wikidata.org/entity/Q85864317"
        mon[:is_castle] = true
      else
        mon[:is_castle] = false
      end


      if mon[:latitude].blank? || mon[:longitude].blank?
        mon[:hidden] = true
      else
        mon[:hidden] = false
      end

      unless mon[:year].nil?
        begin
          if DateTime.parse(mon[:year])&.year != Date.today.year
            mon[:noupload] = true
          else
            mon[:noupload] = false
          end
        rescue Date::Error => e
          mon[:noupload] = false
        end
      end

      unless mon[:enddate].nil?
        if mon[:enddate].to_datetime < Date.today
          mon[:noupload] = true
        else
          mon[:noupload] = false
        end
      end

      mon[:noupload] = false if mon[:noupload].nil?


      monuments_to_be_saved.reject! { |i| i[:item] == mon[:item] } # Elimina duplicati (salvando dunque l'ultimo che arriva) derivanti da dati "sporchi"
      monuments_to_be_saved.push(mon) unless mon[:wlmid].nil?
    end

    monuments_to_be_saved.uniq!

    monuments_to_be_saved.map! { |mon| mon.merge({created_at: DateTime.now, updated_at: DateTime.now})}

    Monument.upsert_all(monuments_to_be_saved, unique_by: :item)

    # Cancella monumenti che non vengono più restituiti dalla query
    items_to_be_deleted = Monument.pluck(:item).uniq - monuments_to_be_saved.pluck(:item).uniq

    items_to_be_deleted.each { |item| Monument.find_by(item: item).destroy }

    # Aggiorna la cache
    CacheWarmJob.perform_later
  end
end
