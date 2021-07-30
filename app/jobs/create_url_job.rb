class CreateUrlJob < ApplicationJob
  queue_as :default

  def createurl(monument, lakecomo)
    basecat = "Images+from+Wiki+Loves+Monuments+#{Date.today.year}+in+Italy"
    mon = HTTParty.get("https://it.wikipedia.org/w/api.php?action=parse&text={{%23invoke:WLM|upload_url|#{monument.item}}}&contentmodel=wikitext&format=json",
                       headers: { 'User-Agent' => 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty Ruby Gem' },
                       uri_adapter: Addressable::URI).to_h
    baselink = mon["parse"]["externallinks"].first + ' '
    monurl = mon["parse"]["externallinks"].first
    monurl.gsub!('(', '%28') # fix parentesi (
    monurl.gsub!(')', '%29') # fix parentesi )

    # Definizione delle regioni
    regioni = {
      'Abruzzo' => ['Abruzzo', true],
      'Basilicata' => ['Basilicata', true],
      'Calabria' => ['Calabria', false],
      'Campania' => ['Campania', false],
      'Emilia-Romagna' => ['Emilia-Romagna', false],
      'Friuli-Venezia Giulia' => ['Friuli-Venezia Giulia', false],
      'Lazio' => ['Lazio', false],
      'Liguria' => ['Liguria', true],
      'Lombardia' => ['Lombardy', false],
      'Marche' => ['Marche', false],
      'Molise' => ['Molise', false],
      'Piemonte' => ['Piedmont', false],
      'Puglia' => ['Apulia', true],
      'Sardegna' => ['Sardinia', false],
      'Sicilia' => ['Sicily', false],
      'Toscana' => ['Tuscany', false],
      'Trentino-Alto Adige' => ['Trentino-South Tyrol', false],
      'Umbria' => ['Umbria', true],
      "Valle d'Aosta" => ['Aosta Valley', false],
      'Veneto' => ['Veneto', true]
    }

    regarr = regioni[monument.regione]

    newstring = '+-+' + regarr[0]
    if regarr[1] == false && !monument.item.in?(lakecomo)
      newstring = newstring + '%7C' + basecat + '+-+' + 'without+local+award'
    end

    newstring = newstring + '%7C' + basecat + '+-+' + 'Lake+Como' if monument.item.in?(lakecomo)
    monurl.gsub!('+-+unknown+region', newstring)

    monument.update!(uploadurl: monurl)

    notwlm = baselink
    notwlm.gsub!('(', '%28') # fix parentesi (
    notwlm.gsub!(')', '%29') # fix parentesi )
    notwlm.gsub!(' ', '')
    notwlm.gsub!('+-+unknown+region', '')
    notwlm.gsub!('&campaign=wlm-it', '')
    notwlm.gsub!("&id=#{monument.wlmid}", '')

    # link non partecipante al concorso
    notwlm.gsub!(/%7CImages\+from\+Wiki\+Loves\+Monuments\+\d{4}\+in\+Italy/, '')
    monument.update!(nonwlmuploadurl: notwlm)
  end

  def perform(*args)
    # Inizio operazioni speciali per WL Lakes Como
    bannedcomo = %w[Q28375375 Q24937411 Q21592570 Q3862651 Q3517634 Q24052892 Q533156]
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
    client = SPARQL::Client.new(endpoint, method: :get,
                                          headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
    comoquery = client.query(sparql)

    comoquery.each do |row|
      row.each do |key, val|
        next unless key.to_s == 'item'

        itemarray = val.to_s.split('/')
        itemcode = itemarray[4]
        lakecomo.push(itemcode.to_s) unless itemcode.in?(bannedcomo)
      end
    end

    # Fine operazioni speciali lakes como    

    Monument.all.each do |monument|
      createurl(monument, lakecomo)
    end
  end
end
