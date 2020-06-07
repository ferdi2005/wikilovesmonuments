class ImportController < ApplicationController
  def do

  end

  def import
    if Rails.env.production? && params[:import][:password] != ENV['PASSWORD']
      render 'do'
      flash[:danger] = 'La password inserita non è corretta'
    else
      Monument.delete_all
      endpoint = "https://query.wikidata.org/sparql"
      sparql = '
      SELECT DISTINCT ?item ?itemLabel ?itemDescription ?coords ?wlmid ?image
      WHERE {
      ?item wdt:P2186 ?wlmid ;
                wdt:P17 wd:Q38 ;
                wdt:P625 ?coords
      OPTIONAL { ?item wdt:P18 ?image }
          MINUS { ?item p:P2186 [ pq:P582 ?end ] .
          FILTER ( ?end <= "2020-09-01T00:00:00+00:00"^^xsd:dateTime )
                }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],it" }
        }'

      client =  SPARQL::Client.new(endpoint, :method => :get, :headers => { 'User-Agent': 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using Sparql gem ruby/2.2.1'})
      monuments = client.query(sparql)

      for row in monuments do
        @mon = Monument.new
        for key,val in row do
          if key.to_s == 'item'
            itemarray = val.to_s.split('/')
            itemcode = itemarray[4]
            @mon.item = itemcode.to_s
          end
          if key.to_s == 'wlmid'
            @mon.wlmid = val.to_s
          end
          if key.to_s == 'coords'
            totalarray = val.to_s.split('(')
            onlylatlong = totalarray[1].split(')')
            latlongarray = onlylatlong[0].split(' ')
            lat = latlongarray[1]
            long = latlongarray[0]
            @mon.latitude = BigDecimal.new(lat)
            @mon.longitude = BigDecimal.new(long)
          end
          if key.to_s == 'itemLabel'
            @mon.itemLabel = val.to_s
          end
          if key.to_s == 'image'
            filename = val.to_s.split('Special:FilePath/')[1]
            @mon.image = filename.to_s
          end
          if key.to_s == "itemDescription"
            @mon.itemDescription = val.to_s
          end
        end
        @mon.save
      end
      redirect_to root_path
      flash[:success] = "Import fatto con successo"
    end
  end
end
