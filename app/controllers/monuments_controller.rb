class MonumentsController < ApplicationController

  def index
    if params[:latitude] && params[:longitude]
      @monument = Monument.near([params[:latitude].to_decimal, params[:longitude].to_decimal],30, units: :km)
    elsif params[:city]
      @monument = Monument.near("#{params[:city]}", 30, units: :km)
    end
  end

  def show
    @monument = Monument.find(params[:id])
  end
end
