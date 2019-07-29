class MonumentsController < ApplicationController
  include Pagy::Backend
  include MonumentsHelper

  def index
    if params[:latitude] && params[:longitude]
      @pagy, @monument = pagy(Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])]))
      @monument_nopagy = Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])])
      @geocenter = [params[:latitude].to_i, params[:longitude].to_i]
    elsif params[:city]
      @pagy, @monument = pagy(Monument.near("#{params[:city]}"))
      @monument_nopagy = Monument.near(params[:city])
      result = Geocoder.search(params[:city])
      @geocenter = result.first.coordinates
    end
  end

  def show
    @monument = Monument.find(params[:format])
  end

  def map
   @monuments = Monument.all
  end 
end
