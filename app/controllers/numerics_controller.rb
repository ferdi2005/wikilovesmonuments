class NumericsController < ApplicationController
    def monuments
        if params[:regione].blank?
            nophotobeforeid = Nophoto.where(regione: nil).last(2).first
            nophoto = { 
                "postfix": "Monumenti",
                "data": [{ 
                    "value": Nophoto.where(regione: nil).last.monuments
                },
                { 
                    "value": nophotobeforeid.monuments
                }
                ]
            }
        else
            nophotobeforeid = Nophoto.where(regione: params[:regione]).last(2).first
            nophoto = { 
                "postfix": "Monumenti",
                "data": [{ 
                    "value": Nophoto.where(regione: params[:regione]).last.monuments
                },
                { 
                    "value": nophotobeforeid.monuments
                }
                ]
            }
        end
        respond_to do |format|
            format.json {render json: nophoto }
        end
    end


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
        if Nophoto.where(created_at: Date.today.midnight...Date.today.end_of_day).empty?
            nophoto = Nophoto.where(created_at: Date.yesterday.midnight...Date.yesterday.end_of_day)
        else
            nophoto = Nophoto.where(created_at: Date.today.midnight...Date.today.end_of_day)
        end
        respond_to do |format|
            format.json {render json: nophoto }
        end
    end

    def allregionscount
    regioni = ['Abruzzo',
            'Basilicata',
            'Calabria',
            'Campania',
            'Emilia-Romagna',
            'Friuli-Venezia Giulia',
            'Lazio',
            'Liguria',
            'Lombardia',
            'Marche',
            'Molise',
            'Piemonte',
            'Puglia',
            'Sardegna',
            'Sicilia',
            'Toscana',
            'Trentino-Alto Adige',
            'Umbria',
            "Valle d'Aosta",
            'Veneto']
            result = {}
        regioni.each do |reg|
            result[reg] = Monument.where(regione: reg).count
        end
        respond_to do |format|
            format.json {render json: result }
        end

    end
end
