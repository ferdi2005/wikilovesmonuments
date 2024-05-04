class GamesController < ApplicationController
  def imagematch
    if session[:secret].nil?
      session[:referer] = request.original_url
      redirect_to start_login_path and return
    end

    @monument = Monument.where(photos_count: 1.., image: nil).sample
    @count = Monument.where(photos_count: 1.., image: nil).count
    search = '"' + @monument.wlmid + '"'
    commons = MediawikiApi::Client.new "https://commons.wikimedia.org/w/api.php"
    @images = commons.query(:list => :search, :srsearch => search, :srwhat => :text, :srnamespace => 6, :srlimit => :max).data["search"]
  end

  def imagematch_save
    if session[:secret].nil?
      session[:referer] = request.original_url
      redirect_to start_login_path and return
    end

    commons = MediawikiApi::Client.new "https://commons.wikimedia.org/w/api.php"
    if (monument = Monument.find(params[:monument][:id]) and monument.image.nil?)

      #client = MediawikiApi::Client.new "https://www.wikidata.org/w/api.php"
      #client.oauth_access_token(session[:access_token])

      @token = OAuth::AccessToken.new($wikidata_oauth_consumer)
      @token.secret = session[:secret]
      @token.token = session[:token]

      csrf_request = JSON.parse(@token.get("https://www.wikidata.org/w/api.php?action=query&format=json&meta=tokens").body)
      csrf = csrf_request.try(:[], "query").try(:[], "tokens").try(:[], "csrftoken")

      if csrf == nil
        if csrf_request.try(:[], "error").try(:[], "code") == "mwoauth-invalid-authorization"
          flash[:error] = csrf_request.try(:[], "error").try(:[], "info")
          redirect_to root_path and return
        else
          flash[:error] = "ERRORE GENERICO. IMPOSSIBILE EFFETTUARE IL LOGIN"
          redirect_to root_path and return
        end
      end

      body = {
        action: "wbcreateclaim",
        entity: monument.item,
        snaktype: 'value',
        property: 'P18',
        value: params[:monument][:image].gsub("File:", "").to_json,
        summary: "Adding image (WLM Italy tools)",
        token: csrf,
        format: "json"
      }

      @response = JSON.parse(@token.post("/w/api.php", body).body)

      if @response["success"]
        monument.update(image: params[:monument][:image].gsub("File:", ""))
        flash[:success] = "Immagine aggiunta con successo"
      else
        flash[:error] = "Errore nel salvataggio dell'immagine #{@response}"
      end
      redirect_to games_imagematch_path
    else
      flash[:error] = "ID non valido"
      redirect_to imagematch_path
    end
  end

  def categorymatch
  end

  def articlematch
  end
end
