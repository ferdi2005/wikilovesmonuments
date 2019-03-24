class MonumentsController < ApplicationController
  include Pagy::Backend

  def index
    if params[:latitude] && params[:longitude]
      @pagy, @monument = pagy(Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])]))
    elsif params[:city]
      @pagy, @monument = pagy(Monument.near("#{params[:city]}"))
    end
  end

  def show
    @monument = Monument.find(params[:format])
  end

  def map
   @monuments = Monument.all
  end 
end
