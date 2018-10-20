class ImportController < ApplicationController
  def do

  end

  def import
    if params[:import][:password] != ENV['PASSWORD']
      render 'do'
      flash[:danger] = 'La password inserita non è corretta'
    else
      Monument.delete_all
      endpoint = "https://query.wikidata.org/sparql"
      sparql = '
      SELECT DISTINCT ?item ?itemLabel (AVG(?lat) AS ?lat) (AVG(?lon) AS ?lon) ?image ?wlmid
      WHERE {
        ?item wdt:P2186 ?wlmid ;
                wdt:P17 wd:Q38 ;
                wdt:P625 ?coords.
                ?item                 p:P625         ?statementnode.
                ?statementnode      psv:P625         ?valuenode.
                ?valuenode     wikibase:geoLatitude  ?lat.
                ?valuenode     wikibase:geoLongitude ?lon.
          OPTIONAL { ?item wdt:P18 ?image }
          MINUS { ?item p:P2186 [ pq:P582 ?end ] .
          FILTER ( ?end <= "2018-09-01T00:00:00+00:00"^^xsd:dateTime ) }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],it"  }
      }
      GROUP BY ?item ?itemLabel ?image ?wlmid'

      client = SPARQL::Client.new(endpoint, :method => :get)
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
          if key.to_s == 'lat'
            @mon.latitude = BigDecimal(val.to_s)
          end
          if key.to_s == 'lon'
            @mon.longitude = BigDecimal(val.to_s)
          end
          if key.to_s == 'itemLabel'
            @mon.itemLabel = val.to_s
          end
          if key.to_s == 'image'
            filename = val.to_s.split('Special:FilePath/')
            @mon.image = filename[1]
          end
        end
        @mon.save
      end
      redirect_to root_path
      flash[:success] = "Import fatto con successo"
    end
  end
end
