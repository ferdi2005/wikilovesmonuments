class MonumentsController < ApplicationController

  def index
    if params[:latitude] && params[:longitude]
      @monument = Monument.near([BigDecimal.new(params[:latitude]), BigDecimal.new(params[:longitude])])
    elsif params[:city]
      @monument = Monument.near("#{params[:city]}")
    end
  end

  def show
    @monument = Monument.find(params[:id])
  end
end
