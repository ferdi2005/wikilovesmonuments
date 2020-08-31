class ImportController < ApplicationController
  def do

  end

  def import
    if Rails.env.production? && params[:import][:password] != ENV['PASSWORD']
      render 'do'
      flash[:danger] = 'La password inserita non è corretta'
    else
      redirect_to root_path
    end
  end
end
