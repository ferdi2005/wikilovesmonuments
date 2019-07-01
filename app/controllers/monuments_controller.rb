class MonumentsController < ApplicationController
  include Pagy::Backend
  include MonumentsHelper

  def index
    if params[:latitude] && params[:longitude]
      @pagy, @monument = pagy(Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])]))
      @monument_nopagy = Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])])
    elsif params[:city]
      @pagy, @monument = pagy(Monument.near("#{params[:city]}"))
      @monument_nopagy = Monument.near(params[:city])
    end
    @geocenter = Geocoder::Calculations.geographic_center(@monument_nopagy)
  end

  def show
    @monument = Monument.find(params[:format])
  end

  def map
   @monuments = Monument.all
  end 
end
