class MonumentsController < ApplicationController
  include Pagy::Backend
  include MonumentsHelper

  def index
    if params[:latitude] && params[:longitude]
      @pagy, @monument = pagy(Monument.where(hidden: nil).near([BigDecimal(params[:latitude]), BigDecimal(params[:longitude])]))
      @monument_nopagy = Monument.where(hidden: nil).near([BigDecimal(params[:latitude]), BigDecimal(params[:longitude])])
      @geocenter = [params[:latitude].to_f, params[:longitude].to_f]
    elsif params[:city]
      @pagy, @monument = pagy(Monument.where(hidden: nil).near("#{params[:city]}, IT"))
      @monument_nopagy = Monument.where(hidden: nil).near("#{params[:city]}, IT")
      result = Geocoder.search("#{params[:city]}, IT")
      @geocenter = result.try(:first).try(:coordinates)
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
    @result = Geocoder.search([@monument.latitude, @monument.longitude])
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
  
  def address
    @monument = Monument.find(params[:id])
    result = Geocoder.search([@monument.latitude, @monument.longitude])
    respond_to do |format|
      format.json { render json: result.first.address }
    end
  end
  def map
    flash[:warning] = "L'utilizzo di questa pagina richiede numerose risorse per il server e per il tuo computer, molto probabilmente si bloccherà facilmente"
   @monuments = Monument.where(hidden: nil)
  end 

  def namesearch
    @monuments = Monument.search(params[:search].strip)
    respond_to do |format|
      format.json { render json: @monuments }
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