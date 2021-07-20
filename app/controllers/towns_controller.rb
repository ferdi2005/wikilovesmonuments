class TownsController < ApplicationController
  def search
    if params[:locale] == "it"
      @towns = Town.search(params[:query], :it)
    else
      @towns = Town.search(params[:query], :en)
    end
    respond_to do |format|
      format.json { render :json => @towns}
    end
  end
end
