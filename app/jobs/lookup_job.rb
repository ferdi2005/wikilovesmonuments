# frozen_string_literal: true

class LookupJob < ApplicationJob
  queue_as :default

  def createurl(monument, lakecomo)
    basecat = "Images+from+Wiki+Loves+Monuments+#{Date.today.year}+in+Italy"
    mon = HTTParty.get("https://it.wikipedia.org/w/api.php?action=parse&text={{%23invoke:WLM|upload_url|#{monument.item}}}&contentmodel=wikitext&format=json",
      headers: { 'User-Agent' => 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty Ruby Gem' },
      uri_adapter: Addressable::URI).to_a
      monurl = mon[0][1]['externallinks'][0]
      regioni = {
        'Abruzzo' => ['Abruzzo', true],
        'Basilicata' => ['Basilicata', true],
        'Calabria' => ['Calabria', false],
        'Campania' => ['Campania', false],
        'Emilia-Romagna' => ['Emilia-Romagna', false],
        'Friuli-Venezia Giulia' => ['Friuli-Venezia Giulia', false],
        'Lazio' => ['Lazio', true],
        'Liguria' => ['Liguria', true],
        'Lombardia' => ['Lombardy', false],
        'Marche' => ['Marche', false],
        'Molise' => ['Molise', false],
        'Piemonte' => ['Piedmont', false],
        'Puglia' => ['Apulia', true],
        'Sardegna' => ['Sardinia', false],
        'Sicilia' => ['Sicily', false],
        'Toscana' => ['Tuscany', true],
        'Trentino-Alto Adige' => ['Trentino-South Tyrol', false],
        'Umbria' => ['Umbria', true],
        "Valle d'Aosta" => ['Aosta Valley', false],
        'Veneto' => ['Veneto', true]
    }

    regarr = regioni[monument.regione]

      newstring = '+-+' + regarr[0]
      if regarr[1] == false && lakecomo == false
        newstring = newstring + '%7C' + basecat + '+-+' + 'without+local+award'
      end

      if monument.item.in?(lakecomo)
        newstring = newstring + '%7C' + basecat + '+-+' + 'Lake+Como'
      end
      monurl.gsub!('+-+unknown+region', newstring)

      monument.update_attribute(:uploadurl, monurl)
  end

  def perform(*_args)
    bannedcomo = ['Q28375375', 'Q24937411', 'Q21592570','Q3862651','Q3517634','Q24052892']
    lakecomo = []
    sparql = '
    SELECT DISTINCT ?item
    WHERE {
    ?item wdt:P2186 ?wlmid ;
              wdt:P17 wd:Q38 ;
          VALUES ?lakecomo { wd:Q16161 wd:Q16199} .
    ?item wdt:P131* ?lakecomo .
  
        MINUS { ?item p:P2186 [ pq:P582 ?end ] .
        FILTER ( ?end <= "2020-09-01T00:00:00+00:00"^^xsd:dateTime )
              }
    SERVICE wikibase:label { bd:serviceParam wikibase:language "it" }
      }
    '
    endpoint = 'https://query.wikidata.org/sparql'
    client = SPARQL::Client.new(endpoint, method: :get, headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
    comoquery = client.query(sparql)  

    comoquery.each do |key, val|
      if key.to_s == 'item'
        itemarray = val.to_s.split('/')
        itemcode = itemarray[4]
        unless itemcode.in?(bannedcomo)
          lakecomo.push(itemcode.to_s)
        end
      end
  end


    Monument.all.each do |monument|
      createurl(monument, lakecomo)
      search = '"' + monument.wlmid + '"'
      retimes = 0
      begin
        count = HTTParty.get("https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=#{search}&srwhat=text&srnamespace=6&srlimit=1&format=json",
                             headers: { 'User-Agent' => 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty Ruby Gem' },
                             uri_adapter: Addressable::URI).to_a
      rescue StandardError
        retimes += 1
        if retimes < 4
          puts "Retrying for ID: #{monument.id} - WLMID: #{monument.wlmid}"
          retry
        else
          puts "Skipping ID: #{monument.id} - WLMID: #{monument.wlmid}"
          next
        end
      end
      totalhits = if count[1][0] == 'continue'
                    count[2][1]['searchinfo']['totalhits']
                  else
                    count[1][1]['searchinfo']['totalhits']
                  end
      if totalhits > 0
        monument.update_attributes(with_photos: true, photos_count: totalhits)
      else
        monument.update_attributes(with_photos: false, photos_count: totalhits)
        unless monument.image.nil? || monument.commons.nil?
          monument.update_attribute(:with_photos, true)
        end  
      end
    end
    nophoto = Monument.where(with_photos: false).count

    Nophoto.create(count: nophoto, monuments: Monument.count, with_commons: Monument.where.not(commons:nil).count, with_image: Monument.where.not(image:nil).count, nowlm: Monument.where(with_photos: true, photos_count: 0).count)



    # crea URL
  end
end
