class ImportController < ApplicationController
  def do

  end

  def import
    if Rails.env.production? && params[:import][:password] != ENV['PASSWORD']
      render 'do'
      flash[:danger] = 'La password inserita non è corretta'
    else
      ImportJob.perform_later
      redirect_to root_path
      flash[:success] = "Import schedulato"  
    end
  end
end
