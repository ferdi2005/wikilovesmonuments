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
        flash[:error] = "Errore nel salvataggio dell'immagine #{@response.truncate(400)}"
        Sentry.capture_exception(@response)
      end
      redirect_to games_imagematch_path
    else
      flash[:error] = "ID non valido"
      redirect_to games_imagematch_path
    end
  end

  def categorymatch
    if session[:secret].nil?
      session[:referer] = request.original_url
      redirect_to start_login_path and return
    end

    if params[:id]
      @monument = Monument.find(params[:id])
    else
      @monument = Monument.where(photos_count: 1.., commons: nil).sample
    end
    @count = Monument.where(photos_count: 1.., commons: nil).count
    search = '"' + @monument.wlmid + '"'
    commons = MediawikiApi::Client.new "https://commons.wikimedia.org/w/api.php"
    @images = commons.query(:list => :search, :srsearch => search, :srwhat => :text, :srnamespace => 6, :srlimit => :max).data["search"]
    categories_query = commons.query(:list => :search, :srsearch => @monument.itemlabel, :srwhat => :text, :srnamespace => 14, :srlimit => :max).data
    @categories = categories_query["search"]
    @totalhits = categories_query["searchinfo"]["totalhits"]
    @father = "Category:#{Town.find_by(item: @monument.city_item).commons}"
    # Definizione del titolo
    if @categories.find { |c| c["title"] == "Category:#{@monument.itemlabel} (#{@monument.city.upcase_first})" }
      flash[:warning] = "Esiste già una categoria intitolata #{@monument.itemlabel} (#{@monument.city}"
      @title = "Category:"
    elsif @categories.find { |c| c["title"].include?("Category:#{@monument.itemlabel.upcase_first}") }
      flash[:warning] = "Esiste già una categoria che include #{@monument.itemlabel}"
      @title = "Category:#{@monument.itemlabel.upcase_first} (#{@monument.city.upcase_first})"
    else
      @title = "Category:#{@monument.itemlabel.upcase_first}"
    end
  end

  def categorymatch_save
    begin
      if session[:secret].nil?
        session[:referer] = request.original_url
        redirect_to start_login_path and return
      end

      unless params[:monument][:title].starts_with?("Category:") || params[:monument][:father].starts_with?("Category:")
        flash[:error] = "Il titolo della categoria o della categoria padre deve iniziare con Category:"
        redirect_to games_categorymatch_path(id: params[:monument][:id]) and return
      end

      if (monument = Monument.find(params[:monument][:id]) and monument.commons.nil?)

        messages = []
        errors = []

        #client = MediawikiApi::Client.new "https://www.wikidata.org/w/api.php"
        #client.oauth_access_token(session[:access_token])

        @commons = OAuth::AccessToken.new($commons_oauth_consumer)
        @commons.secret = session[:secret]
        @commons.token = session[:token]

        commons_csrf_request = JSON.parse(@commons.get("https://commons.wikimedia.org/w/api.php?action=query&format=json&meta=tokens").body)
        commons_csrf = commons_csrf_request.try(:[], "query").try(:[], "tokens").try(:[], "csrftoken")

        if commons_csrf == nil
          if commons_csrf_request.try(:[], "error").try(:[], "code") == "mwoauth-invalid-authorization"
            flash[:error] = commons_csrf_request.try(:[], "error").try(:[], "info")
            redirect_to games_categorymatch_path(id: params[:monument][:id]) and return
          else
            flash[:error] = "ERRORE GENERICO. IMPOSSIBILE EFFETTUARE IL LOGIN"
            redirect_to games_categorymatch_path(id: params[:monument][:id]) and return
          end
        end

        commons_body = {
          action: "edit",
          title: params[:monument][:title],
          text: "{{Wikidata Infobox}}
          {{it|#{monument.itemlabel}}}
          [[#{params[:monument][:father]}]]",
          summary: "Creating category for monument",
          createonly: "1",
          token: commons_csrf,
          format: "json",
        }

        @commons_response = JSON.parse(@commons.post("/w/api.php", commons_body).body)

        if @commons_response["edit"]["result"]
          messages.push("Categoria #{params[:monument][:title]} creata.")
        else
          flash[:error] = "Errore nella creazione della categoria #{@response}"
          #redirect_to games_categorymatch_path(id: params[:monument][:id]) and return
        end
        @photos = params.to_unsafe_h[:monument]
        @photos.delete("id")
        @photos.delete("title")
        @photos.delete("father")
        @photos = @photos.keys

        @photos.each do |photo|
          commons_csrf_request = JSON.parse(@commons.get("https://commons.wikimedia.org/w/api.php?action=query&format=json&meta=tokens").body)
          commons_csrf = commons_csrf_request.try(:[], "query").try(:[], "tokens").try(:[], "csrftoken")

          if commons_csrf == nil
            if commons_csrf_request.try(:[], "error").try(:[], "code") == "mwoauth-invalid-authorization"
              errors.push("Errore nel recuperare il CSRF su #{photo}:" + commons_csrf_request.try(:[], "error").try(:[], "info"))
              next
            else
              errors.push("ERRORE GENERICO SU #{photo}. IMPOSSIBILE EFFETTUARE IL LOGIN")
              next
            end
          end

          photo_body = {
            action: "edit",
            title: photo,
            appendtext: "[[#{params[:monument][:title]}]]",
            summary: "Adding photo to category",
            token: commons_csrf,
            nocreate: "1",
            format: "json"
          }

          @photo_response = JSON.parse(@commons.post("/w/api.php", photo_body).body)
        end

        @wikidata = OAuth::AccessToken.new($wikidata_oauth_consumer)
        @wikidata.secret = session[:secret]
        @wikidata.token = session[:token]

        wikidata_csrf_request = JSON.parse(@wikidata.get("https://www.wikidata.org/w/api.php?action=query&format=json&meta=tokens").body)
        wikidata_csrf = wikidata_csrf_request.try(:[], "query").try(:[], "tokens").try(:[], "csrftoken")

        if wikidata_csrf == nil
          if wikidata_csrf_request.try(:[], "error").try(:[], "code") == "mwoauth-invalid-authorization"
            errors.push("Impossibile aggiornare elemento wikidata errore nel token CSRF:" +  wikidata_csrf_request.try(:[], "error").try(:[], "info"))
          else
            errors.push("Impossibile aggiornare elemento wikidata errore generico nel token CSRF")
          end
        end

        wikidata_sitelink_body = {
          action: "wbsetsitelink",
          id: monument.item,
          linksite: "commonswiki",
          linktitle: params[:monument][:title],
          summary: "Adding sitelink to Wikimedia Commons (WLM Italy tools)",
          token: wikidata_csrf,
          format: "json"
        }

        if wikidata_csrf.blank?
          errors.push("Impossibile aggiornare l'item wikidata per #{monument.item}con il sitelink #{params[:monument][:title]}")
        else
          @wikidata_sitelink_response = JSON.parse(@wikidata.post("/w/api.php", wikidata_sitelink_body).body)
          logger.info @wikidata_sitelink_response

          if @wikidata_sitelink_response["success"]
            messages.push("Sitelink aggiunto a Wikidata.")
          else
            errors.push("Errore nell'aggiungimento della categoria a Wikidata")
          end
        end

        wikidata_body = {
          action: "wbcreateclaim",
          entity: monument.item,
          snaktype: 'value',
          property: 'P373',
          value: params[:monument][:title].gsub("Category:", "").to_json,
          summary: "Adding category (WLM Italy tools)",
          token: wikidata_csrf,
          format: "json"
        }

        if wikidata_csrf.blank?
          errors.push("Impossibile aggiornare l'item wikidata per #{monument.item}con la categoria #{params[:monument][:title]}")
        else
          @wikidata_response = JSON.parse(@wikidata.post("/w/api.php", wikidata_body).body)

          if @wikidata_response["success"]
            monument.update(commons: params[:monument][:title].gsub("Category:", ""))
            messages.push("Categoria aggiunta a Wikidata.")
          else
            errors.push("Errore nell'aggiungimento della categoria a Wikidata")
          end
        end

        flash[:success] = messages.join("\n")
        flash[:error] = errors.join("\n")
        redirect_to games_categorymatch_path
      else
        flash[:error] = "ID non valido"
        redirect_to games_categorymatch_path
      end

    rescue => e
      Sentry.capture_exception(e)
      flash[:error] = e.truncate(400)
      redirect_to games_categorymatch_path
    end
  end

  def articlematch
  end
end
