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
      wlmids = Monument.where(city: mon.city).pluck(:wlmid)
      selected = wlmids.select { |id| id.match?(/^\d{2}[A-Z]\d{3}\d{4}$/)}
      if selected.empty?
        nextid = selected.sort.last[6..10].to_i + 1
        newid = nextid.to_s.rjust(4, "0")
        freeid = "#{selected.sort.last[0..5]}#{newid}"
        result = freeid
        if Monument.where(wlmid: result).any?
          result = "Errore! Qualcosa è andato storto!"
        end
      else
        result = "Nessun monumento con l'ID nel formato usuale nella città (es. 16A6620001)"
      end
    else
      result = "Nessun monumento trovato"
    end
    respond_to do |format|
      format.json { render :json => result}
    end
  end
end