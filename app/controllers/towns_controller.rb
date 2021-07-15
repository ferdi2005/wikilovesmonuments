class TownsController < ApplicationController
  def search
    respond_to do |format|
      format.json { render :json => Town.search(params[:query])}
    end
  end
end
