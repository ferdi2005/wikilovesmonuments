# frozen_string_literal: true

require "uri"

# Genera localmente gli URL per Special:UploadWizard su Wikimedia Commons
# replicando la logica di Modulo:WLM su it.wikipedia.org senza chiamate API.
class UploadUrlBuilder
  BASE_URL = "https://commons.wikimedia.org/wiki/Special:UploadWizard".freeze

  BANNED_COMO = %w[Q28375375 Q24937411 Q21592570 Q3862651 Q3517634 Q24052892 Q533156].freeze

  VALLE_DEL_PRIMO_PRESEPE = %w[
    Q223423 Q223427 Q223434 Q223459 Q223472 Q223476 Q223509 Q224039 Q224043 Q118085
    Q224109 Q224144 Q224149 Q224172 Q224211 Q224264 Q224300 Q224333 Q13396 Q224405
  ].freeze

  TERRE_DELL_UFITA = %w[Q55007 Q55008 Q55016 Q55033 Q55036 Q55042 Q55085 Q55121 Q55139].freeze

  REGIONI = {
    "Abruzzo" => ["Abruzzo", true],
    "Basilicata" => ["Basilicata", true],
    "Calabria" => ["Calabria", true],
    "Campania" => ["Campania", false],
    "Emilia-Romagna" => ["Emilia-Romagna", false],
    "Friuli-Venezia Giulia" => ["Friuli-Venezia Giulia", true],
    "Lazio" => ["Lazio", true],
    "Liguria" => ["Liguria", true],
    "Lombardia" => ["Lombardy", true],
    "Marche" => ["Marche", true],
    "Molise" => ["Molise", false],
    "Piemonte" => ["Piedmont", true],
    "Puglia" => ["Apulia", true],
    "Sardegna" => ["Sardinia", false],
    "Sicilia" => ["Sicily", false],
    "Toscana" => ["Tuscany", true],
    "Trentino-Alto Adige" => ["Trentino-South Tyrol", false],
    "Umbria" => ["Umbria", false],
    "Valle d'Aosta" => ["Aosta Valley", false],
    "Veneto" => ["Veneto", true]
  }.freeze

  class << self
    def build_urls(monument_attrs, year: Date.today.year, lakecomo_items: [], fallback_commons: nil, religious: false)
      wlmid = extract_attr(monument_attrs, :wlmid)
      regione = extract_attr(monument_attrs, :regione)
      regarr = REGIONI[regione]

      return { uploadurl: nil, nonwlmuploadurl: nil } if wlmid.blank? || regarr.nil?

      item = extract_attr(monument_attrs, :item)
      itemlabel = extract_attr(monument_attrs, :itemlabel)
      latitude = extract_attr(monument_attrs, :latitude)
      longitude = extract_attr(monument_attrs, :longitude)
      commons = extract_attr(monument_attrs, :commons)
      city_item = extract_attr(monument_attrs, :city_item)
      tree = extract_attr(monument_attrs, :tree)
      is_castle = extract_attr(monument_attrs, :is_castle)

      main_cat = commons.presence || fallback_commons.presence
      basecat = "Images from Wiki Loves Monuments #{year} in Italy"

      categories = []
      categories << main_cat if main_cat
      categories << "#{basecat} - veteran trees" if tree
      categories << (religious ? "#{basecat} - religious buildings" : "#{basecat} - traditional contest")

      reg_name, has_local_award = regarr
      if is_castle
        categories << "#{basecat} - #{reg_name} - fortifications"
      elsif religious
        categories << "#{basecat} - #{reg_name} - religious buildings"
      else
        categories << "#{basecat} - #{reg_name}"
      end

      in_lakecomo = lakecomo_items.include?(item) && !BANNED_COMO.include?(item)
      in_presepe = VALLE_DEL_PRIMO_PRESEPE.include?(city_item) || VALLE_DEL_PRIMO_PRESEPE.include?(item)
      in_ufita = TERRE_DELL_UFITA.include?(city_item) || TERRE_DELL_UFITA.include?(item)

      if !has_local_award && !in_lakecomo && !in_presepe && !in_ufita
        categories << "#{basecat} - without local award"
      end
      categories << "#{basecat} - Lake Como" if in_lakecomo
      categories << "#{basecat} - Valle del Primo Presepe" if in_presepe
      categories << "#{basecat} - Terre dell'Ufita" if in_ufita

      common_params = {
        "uselang" => "it",
        "descriptionlang" => "it"
      }
      common_params["description"] = itemlabel.to_s if itemlabel.present?
      if latitude.present? && longitude.present?
        common_params["lat"] = format_coord(latitude)
        common_params["lon"] = format_coord(longitude)
      end

      wlm_params = {
        "campaign" => "wlm-it",
        "id" => wlmid.to_s
      }.merge(common_params).merge("categories" => categories.join("|"))

      nonwlm_params = common_params.dup
      nonwlm_params["categories"] = main_cat if main_cat

      {
        uploadurl: encode_url(wlm_params),
        nonwlmuploadurl: encode_url(nonwlm_params)
      }
    end

    private

    def extract_attr(obj, key)
      if obj.is_a?(Hash)
        obj[key] || obj[key.to_s]
      else
        obj.public_send(key)
      end
    end

    def format_coord(value)
      value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
    end

    def encode_url(params)
      query = URI.encode_www_form(params).gsub("(", "%28").gsub(")", "%29")
      "#{BASE_URL}?#{query}"
    end
  end
end
