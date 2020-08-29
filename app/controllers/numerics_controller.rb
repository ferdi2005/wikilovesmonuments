class NumericsController < ApplicationController
    def nophoto
        if params[:regione].blank?
            nophotobeforeid = Nophoto.where(regione: nil).last(2).first
            nophoto = { 
                "postfix": "Monumenti senza foto",
                "data": [{ 
                    "value": Nophoto.where(regione: nil).last.count
                },
                { 
                    "value": nophotobeforeid.count
                }
                ]
            }
        else
            nophotobeforeid = Nophoto.where(regione: params[:regione]).last(2).first
            nophoto = { 
                "postfix": "Monumenti senza foto",
                "data": [{ 
                    "value": Nophoto.where(regione: params[:regione]).last.count
                },
                { 
                    "value": nophotobeforeid.count
                }
                ]
            }
        end
        respond_to do |format|
            format.json {render json: nophoto }
        end
    end

    def nophotograph
        if params[:regione].blank?
            hashdata = []
            Nophoto.where(regione: nil).last(31).each do |nophoto|
                hashdata.push({"value": nophoto.count})
            end
            nophoto = { 
                "postfix": "Monumenti senza foto (grafico)",
                "data": hashdata
            }
        else
            hashdata = []
            Nophoto.where(regione: params[:regione]).last(31).each do |nophoto|
                hashdata.push({"value": nophoto.count})
            end
            nophoto = { 
                "postfix": "Monumenti senza foto (grafico)",
                "data": hashdata
            }

        end
        respond_to do |format|
            format.json {render json: nophoto }
        end
    end

    def allregionsdifference
        date = Date.today
        nophoto = Nophoto.where(created_at: date.midnight...date.end_of_day)
        respond_to do |format|
            format.json {render json: nophoto }
        end
    end
end
