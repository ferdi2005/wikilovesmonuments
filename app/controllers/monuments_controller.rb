class MonumentsController < ApplicationController
  include Pagy::Backend
  include MonumentsHelper

  def index
    if params[:latitude] && params[:longitude]
      @pagy, @monument = pagy(Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])]))
      @monument_nopagy = Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])])
      @geocenter = [params[:latitude].to_f, params[:longitude].to_f]
    elsif params[:city]
      @pagy, @monument = pagy(Monument.near("#{params[:city]}"))
      @monument_nopagy = Monument.near(params[:city])
      result = Geocoder.search(params[:city])
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

  def map
    flash[:warning] = "L'utilizzo di questa pagina richiede numerose risorse per il server e per il tuo computer, molto probabilmente si bloccherà facilmente"
   @monuments = Monument.all
  end 
end