class MonumentsController < ApplicationController
  include Pagy::Backend
  include MonumentsHelper
  include Skylight::Helpers

  caches_page :map

  def index
    if params[:latitude] && params[:longitude]
      if !params[:range].blank?
        range = params[:range].to_i
      else
        range = 50
      end
      @pagy, @monument = pagy(Monument.where(hidden: false).near([BigDecimal(params[:latitude]), BigDecimal(params[:longitude])], range, units: :km))
      @monument_nopagy = Monument.where(hidden: false).near([BigDecimal(params[:latitude]), BigDecimal(params[:longitude])], range, units: :km)
      @geocenter = [params[:latitude].to_f, params[:longitude].to_f]
    elsif params[:city]
      @pagy, @monument = pagy(Monument.where(hidden: false).near("#{params[:city]}, IT"))
      @monument_nopagy = Monument.where(hidden: false).near("#{params[:city]}, IT")
      result = Geocoder.search("#{params[:city]}, IT")
      @geocenter = result.try(:first).try(:coordinates)
    elsif params[:townid]
      town = Town.find_by(item: params[:townid])
      if town.latitude != nil && town.longitude != nil
        @pagy, @monument = pagy(Monument.where(hidden: false).near(town))
        @monument_nopagy = Monument.where(hidden: false).near(town)
        @geocenter = [town.latitude, town.longitude]
      else 
        @pagy, @monument = pagy(Monument.where(hidden: false).near("#{town.search_name}, IT"))
        @monument_nopagy = Monument.where(hidden: false).near("#{town.search_name}, IT")
        result = Geocoder.search("#{town.search_name}, IT")
        @geocenter = result.try(:first).try(:coordinates)
      end
    else
      @monument = []
    end
    respond_to do |format|
      format.html
      format.json { render json: [@monument_nopagy, @geocenter] }
    end
  end

  def show
    @monument = Monument.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: @monument }
    end
  end


  def show_by_wlmid
    @monument = Monument.find_by(wlmid: params[:wlmid])
    respond_to do |format|
      format.html { redirect_to show_path(id: @monument.id)}
      format.json { render json: @monument }
    end
  end

  def show_by_wikidata
    @monument = Monument.find_by(item: params[:item])
    respond_to do |format|
      format.html { redirect_to show_path(id: @monument.id)}
      format.json { render json: @monument }
    end
  end

  
  def address
    @monument = Monument.find(params[:id])
    result = Geocoder.search([@monument.latitude, @monument.longitude]).try(:first).try(:address)
    respond_to do |format|
      if result.nil?
        format.json { render json: nil, status: :not_found }
      else
        format.json { render json: result }
      end
    end
  end

  def map
  @regioni = ["Marche",                                     
      "Lombardia",                                  
      "Piemonte",                                   
      "Liguria",                                    
      "Sicilia",                                    
      "Lazio",                                      
      "Campania",                                   
      "Basilicata",                                 
      "Abruzzo",                                    
      "Emilia-Romagna",                             
      "Puglia",                                     
      "Umbria",                                     
      "Toscana",                                    
      "Valle d'Aosta",                              
      "Friuli-Venezia Giulia",
      "Sardegna",
      "Molise",
      "Veneto",
      "Calabria",
      "Trentino-Alto Adige"]  
   @monuments = Monument.where(hidden: false)
  end 

  def namesearch
    @monuments = Monument.search(params[:search].strip)
    respond_to do |format|
      if params[:lat].blank? || params[:lon].blank?
        format.json { render json: @monuments }
      else 
        format.json { render json: @monuments.as_json.map {|mon| mon.merge!({"distance": Monument.find(mon["id"]).distance_to([params[:lat], params[:lon]])})} }
      end
    end
  end

  def inscadenza
    @monument = Monument.where.not(enddate: nil).sort_by { |m| m.enddate }
  end

  def nextid; end

  def findnextid
    if (mon = Monument.find_by(item: params[:id]))
      case mon.find_next_id
      when 0
        result = "Errore! Qualcosa è andato storto!"
      when 1
        result = "Nessun monumento con l'ID nel formato usuale nella città (es. 16A6620001)"
      else
        result = mon.find_next_id
      end
    else
      result = "Nessun monumento trovato"
    end
    respond_to do |format|
      format.json { render :json => result}
    end
  end

  def doppioni
    @monuments = Monument.where(duplicate: true)
  end
end