class CreateUrlJob < ApplicationJob
  queue_as :default

  def createurl(monument)
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
      'Calabria' => ['Calabria', true],
      'Campania' => ['Campania', false],
      'Emilia-Romagna' => ['Emilia-Romagna', false],
      'Friuli-Venezia Giulia' => ['Friuli-Venezia Giulia', true],
      'Lazio' => ['Lazio', true],
      'Liguria' => ['Liguria', true],
      'Lombardia' => ['Lombardy', true],
      'Marche' => ['Marche', true],
      'Molise' => ['Molise', false],
      'Piemonte' => ['Piedmont', true],
      'Puglia' => ['Apulia', true],
      'Sardegna' => ['Sardinia', false],
      'Sicilia' => ['Sicily', false],
      'Toscana' => ['Tuscany', true],
      'Trentino-Alto Adige' => ['Trentino-South Tyrol', false],
      'Umbria' => ['Umbria', false],
      "Valle d'Aosta" => ['Aosta Valley', false],
      'Veneto' => ['Veneto', true]
    }

    regarr = regioni[monument.regione]
    
    if monument.is_castle
      newstring = '+-+' + regarr[0] + "+-+fortifications"
    else
      newstring = '+-+' + regarr[0]
    end

   if regarr[1] == false && !monument.item.in?(@lakecomo) && !monument.city_item.in?(@valle_del_primo_presepe) && !monument.city_item.in?(@terre_dell_ufita)
      newstring = newstring + '%7C' + basecat + '+-+' + 'without+local+award'
    end

    newstring = newstring + '%7C' + basecat + '+-+' + 'Lake+Como' if monument.item.in?(@lakecomo)
    newstring = newstring + '%7C' + basecat + '+-+' + 'Valle+del+Primo+Presepe' if monument.city_item.in?(@valle_del_primo_presepe)

    # Terre dell'Uftia
    newstring = newstring + '%7C' + basecat + '+-+' + 'Terre+dell%27Ufita' if monument.city_item.in?(@terre_dell_ufita)

    monurl.gsub!('+-+unknown+region', newstring)

    notwlm = baselink
    notwlm.gsub!('(', '%28') # fix parentesi (
    notwlm.gsub!(')', '%29') # fix parentesi )
    notwlm.gsub!(' ', '')
    notwlm.gsub!('+-+unknown+region', '')
    notwlm.gsub!('&campaign=wlm-it', '')
    notwlm.gsub!("&id=#{monument.wlmid}", '')

    # link non partecipante al concorso
    notwlm.gsub!(/%7CImages\+from\+Wiki\+Loves\+Monuments\+\d{4}\+in\+Italy/, '')

    # Aggiorno nel database
    monument.update!(uploadurl: monurl, nonwlmuploadurl: notwlm)
  end

  def perform(*args)
    # Inizio operazioni speciali per WL Lakes Como
    bannedcomo = %w[Q28375375 Q24937411 Q21592570 Q3862651 Q3517634 Q24052892 Q533156]
    @lakecomo = []
    sparql = '
    SELECT DISTINCT ?item
    WHERE {
    ?item wdt:P2186 ?wlmid ;
              wdt:P17 wd:Q38 ;
          VALUES ?lakecomo { wd:Q16161 wd:Q16199} .
    ?item wdt:P131* ?lakecomo .

        MINUS { ?item p:P2186 [ pq:P582 ?end ] .
        FILTER ( ?end <= "' + Date.today.year.to_s + '-09-01T00:00:00+00:00"^^xsd:dateTime )
              }
    SERVICE wikibase:label { bd:serviceParam wikibase:language "it" }
      }
    '
    endpoint = 'https://query.wikidata.org/sparql'
    client = SPARQL::Client.new(endpoint, method: :get,
                                          headers: { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1' })
    comoquery = client.query(sparql)

    comoquery.each do |como|
        itemarray = como[:item].to_s.split('/')
        itemcode = itemarray[4]
        @lakecomo.push(itemcode.to_s) unless itemcode.in?(bannedcomo)
    end

    # Fine operazioni speciali lakes como    

    # Comuni partecipanti a Valle del primo presepe
    @valle_del_primo_presepe = %w[Q223423 Q223427 Q223434 Q223459 Q223472 Q223476 Q223509 Q224039 Q224043 Q118085 Q224109 Q224144 Q224149 Q224172 Q224211 Q224264 Q224300 Q224333 Q13396 Q224405]

    @terre_dell_ufita = %w[Q55007 Q55008 Q55016 Q55033 Q55036 Q55042 Q55085 Q55121 Q55139]

    Monument.find_each do |monument|
      createurl(monument)
    end
  end
end
