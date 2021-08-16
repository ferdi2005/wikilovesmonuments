class UsersController < ApplicationController

  def authorize_user(uuid, token)
    # Registra il login e procede con l'autenticazione

    # Verifica lingua
    request.env['HTTP_ACCEPT_LANGUAGE'].include?("it") ? language = "it" : language = "en" # TODO: RENDERE PIÙ TRADUCIBILE IN ALTRE LINGUE 
    
    # Verifica wiki di test
    cookies["wiki"].blank? ? wiki = "mediawiki" : wiki = "wikitest"

    if HTTParty.post(ENV["UPLOADS_BACKEND"] + "/set_credentials.json", body: { uuid: uuid, token: token, device_name: request.user_agent }).status == 202
      redirect_to ENV["UPLOADS_BACKEND"] + "/start_login?uuid=#{uuid}&token=#{token}&language=#{language}&wiki=#{wiki}&monument=#{monument.item}"
    else
      flash[:danger] = "Si è verificato un errore"
      redirect_to root_path and return
    end
  end

  def get
    # get_or_set

    redirect_to root_path and return unless (monument = Monument.find_by(id: params[:monument]))
    if cookies.encrypted.permanent[:uuid].blank? || cookies.encrypted.permanent[:token].blank?
      cookies.delete :uuid
      cookies.delete :secret_token
      
      # Genera randomicamente uuid e token
      uuid = SecureRandom.uuid
      token = SecureRandom.uuid
      cookies.encrypted.permanent[:uuid] = uuid
      cookies.encrypted.permanent[:token] = token
      
      authorize_user(uuid, token)
    else
      uuid = cookies.encrypted.permanent[:uuid]
      token = cookies.encrypted.permanent[:token]
      response = HTTParty.get(ENV["UPLOADS_BACKEND"] + "/userinfo.json", query: { uuid: uuid, token: token }).to_h

      unless response["error"].blank?
        flash[:danger] = "Utente non trovato"
        redirect_to root_path and return
      end

      if response["authorized"] == false
        authorize_user(uuid, token)
      else
        redirect_to upload_path(monument: monument.id)
      end
    end
  end

  def destroy
    uuid = cookies.encrypted.permanent[:uuid]
    token = cookies.encrypted.permanent[:token]
    HTTParty.get(ENV["UPLOADS_BACKEND"] + "/deleteuser.json", query: { uuid: uuid, token: token })

    cookies.delete :uuid
    cookies.delete :secret_token
    flash[:success] = "Il logout è stato effettuato."
    redirect_to root_path
  end
end
