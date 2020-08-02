class NumericsController < ApplicationController
    def nophoto
        nophotobeforeid = Nophoto.last.id - 1
        nophoto = { 
            "postfix": "Monumenti senza foto",
            "data": [{ 
                "value": Monument.where(with_photos: false).count
             },
             { 
                 "value": Nophoto.find(nophotobeforeid).count
              }
            ]
         }
        respond_to do |format|
            format.json {render json: nophoto }
        end
    end
end