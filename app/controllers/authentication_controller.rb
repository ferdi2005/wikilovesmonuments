class AuthenticationController < ApplicationController
  def success
    flash[:success] = "Grazie per aver eseguito l'accesso"
    redirect_to session[:referer] || root_path and session.delete(:referer)
  end

  def failure
    flash[:error] = "Errore nell'autenticazione"
    redirect_to root_path
  end

  def start
    request_token = $oauth_consumer.get_request_token(:oauth_callback => "oob")
    session["oauth_session"] = request_token.token
    session["oauth_secret"] = request_token.secret

    redirect_to request_token.authorize_url(:oauth_callback => "oob")
  end

  def process_data
    begin
      hash = { oauth_token: session["oauth_session"], oauth_token_secret: session["oauth_secret"]}
      request_token = OAuth::RequestToken.from_hash($oauth_consumer, hash)
      access_token = request_token.get_access_token(oauth_verifier: params[:oauth_verifier])
      session[:token] = access_token.token
      session[:secret] = access_token.secret

      redirect_to success_path
    rescue => e
      logger.error e
      redirect_to root_path
    end
  end

end
