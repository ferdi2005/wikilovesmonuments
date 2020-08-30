class MonumentsController < ApplicationController
  include Pagy::Backend
  include MonumentsHelper

  def index
    if params[:latitude] && params[:longitude]
      @pagy, @monument = pagy(Monument.where(hidden: nil).near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])]))
      @monument_nopagy = Monument.where(hidden: nil).near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])])
      @geocenter = [params[:latitude].to_f, params[:longitude].to_f]
    elsif params[:city]
      @pagy, @monument = pagy(Monument.where(hidden: nil).near("#{params[:city]}, IT"))
      @monument_nopagy = Monument.where(hidden: nil).near("#{params[:city]}, IT")
      result = Geocoder.search("#{params[:city]}, IT")
      @geocenter = result.try(:first).try(:coordinates)
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
end