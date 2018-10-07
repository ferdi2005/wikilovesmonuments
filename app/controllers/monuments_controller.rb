class MonumentsController < ApplicationController

  def index
    #TODO: Set Location
    @monuments = Monuments.near(location: '')
  end

  def show
    @monument = Monuments.find(params[:id])
  end
end
