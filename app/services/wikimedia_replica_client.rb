require "set"
require "json"
require "bigdecimal"
require "uri"

# Client in sola lettura per interrogare le database replica di Wikimedia Toolforge
# (commonswiki_p su cluster core s4 e links x4) senza effettuare richieste HTTP alle API MediaWiki.
class WikimediaReplicaClient
  KNOWN_IDS_CATEGORY = "Cultural_heritage_monuments_in_Italy_with_known_IDs".freeze
  QUALITY_IMAGES_CATEGORY = "Quality_images".freeze
  FEATURED_PICTURES_CATEGORY = "Featured_pictures_on_Wikimedia_Commons".freeze
  BATCH_SIZE = 1000
  METADATA_BATCH_SIZE = 200

  class << self
    def enabled?
      ENV["TOOLFORGE"].to_s.downcase == "true" || ENV["USE_TOOLFORGE_REPLICAS"].to_s.downcase == "true"
    end

    def normalize_category_title(title)
      title.to_s.strip.sub(/\ACategory:/i, "").tr(" ", "_")
    end

    def normalize_file_title(title)
      title.to_s.strip.sub(/\AFile:/i, "").tr(" ", "_")
    end

    def denormalize_file_title(db_title)
      "File:#{decode(db_title).to_s.tr('_', ' ')}"
    end

    def decode(val)
      return nil if val.nil?

      val.to_s.dup.force_encoding(Encoding::UTF_8).scrub
    end

    def pad_wlmid(wlmid)
      wlmid.to_s.strip.rjust(10, "0")
    end

    def wlmid_candidates(raw_sortkey)
      raw = raw_sortkey.to_s.strip
      return [] if raw.empty?

      candidates = [raw]
      current = raw
      while current.start_with?("0") && current.length > 1
        current = current[1..]
        candidates << current
      end
      candidates.uniq
    end

    def reset_schema_cache!
      @uses_file_revision_tables = nil
      @categorylinks_uses_linktarget = nil
    end

    def uses_file_revision_tables?
      return @uses_file_revision_tables unless @uses_file_revision_tables.nil?

      @uses_file_revision_tables =
        commons_connection.data_source_exists?("filerevision") &&
        commons_connection.data_source_exists?("file")
    end

    def categorylinks_uses_linktarget?
      return @categorylinks_uses_linktarget unless @categorylinks_uses_linktarget.nil?

      @categorylinks_uses_linktarget =
        commons_links_connection.column_exists?("categorylinks", "cl_target_id")
    end

    def fetch_category_files_counts(category_titles)
      normalized = category_titles.filter_map do |title|
        norm = normalize_category_title(title)
        norm unless norm.empty?
      end.uniq
      return {} if normalized.empty?

      conn = commons_connection
      counts = {}

      normalized.each_slice(BATCH_SIZE) do |slice|
        quoted = slice.map { |t| conn.quote(t) }.join(", ")
        sql = <<~SQL
          SELECT cat_title, cat_files
          FROM category
          WHERE cat_title IN (#{quoted})
        SQL

        conn.select_all(sql).each do |row|
          counts[decode(row["cat_title"])] = row["cat_files"].to_i
        end
      end

      counts
    end

    def fetch_wlm_photo_stats
      conn = commons_links_connection

      sql = if categorylinks_uses_linktarget?
              lt_ids = fetch_category_linktarget_ids(
                conn,
                [KNOWN_IDS_CATEGORY, QUALITY_IMAGES_CATEGORY, FEATURED_PICTURES_CATEGORY]
              )
              known_ids_lt_id = lt_ids[KNOWN_IDS_CATEGORY]
              return {} if known_ids_lt_id.nil?

              qi_lt_id = lt_ids[QUALITY_IMAGES_CATEGORY]
              fp_lt_id = lt_ids[FEATURED_PICTURES_CATEGORY]

              qi_join = if qi_lt_id
                          "LEFT JOIN categorylinks cl_qi ON cl_qi.cl_from = cl.cl_from AND cl_qi.cl_target_id = #{qi_lt_id.to_i}"
                        else
                          ""
                        end
              fp_join = if fp_lt_id
                          "LEFT JOIN categorylinks cl_fp ON cl_fp.cl_from = cl.cl_from AND cl_fp.cl_target_id = #{fp_lt_id.to_i}"
                        else
                          ""
                        end

              qi_select = qi_lt_id ? "COUNT(cl_qi.cl_from) AS quality_count" : "0 AS quality_count"
              fp_select = fp_lt_id ? "COUNT(cl_fp.cl_from) AS featured_count" : "0 AS featured_count"

              <<~SQL
                SELECT
                  cl.cl_sortkey_prefix AS sortkey_prefix,
                  COUNT(*) AS photos_count,
                  #{qi_select},
                  #{fp_select}
                FROM categorylinks cl
                #{qi_join}
                #{fp_join}
                WHERE cl.cl_target_id = #{known_ids_lt_id.to_i}
                  AND cl.cl_type = 'file'
                  AND cl.cl_sortkey_prefix != ''
                GROUP BY cl.cl_sortkey_prefix
              SQL
            else
              quoted_known = conn.quote(KNOWN_IDS_CATEGORY)
              quoted_qi = conn.quote(QUALITY_IMAGES_CATEGORY)
              quoted_fp = conn.quote(FEATURED_PICTURES_CATEGORY)

              <<~SQL
                SELECT
                  cl.cl_sortkey_prefix AS sortkey_prefix,
                  COUNT(*) AS photos_count,
                  COUNT(cl_qi.cl_from) AS quality_count,
                  COUNT(cl_fp.cl_from) AS featured_count
                FROM categorylinks cl
                LEFT JOIN categorylinks cl_qi
                  ON cl_qi.cl_from = cl.cl_from
                 AND cl_qi.cl_to = #{quoted_qi}
                LEFT JOIN categorylinks cl_fp
                  ON cl_fp.cl_from = cl.cl_from
                 AND cl_fp.cl_to = #{quoted_fp}
                WHERE cl.cl_to = #{quoted_known}
                  AND cl.cl_type = 'file'
                  AND cl.cl_sortkey_prefix != ''
                GROUP BY cl.cl_sortkey_prefix
              SQL
            end

      stats = {}
      conn.select_all(sql).each do |row|
        prefix = decode(row["sortkey_prefix"])&.strip
        next if prefix.nil? || prefix.empty?

        stats[prefix] = {
          photos_count: row["photos_count"].to_i,
          quality_count: row["quality_count"].to_i,
          featured_count: row["featured_count"].to_i
        }
      end
      stats
    end

    def lookup_stats_for_wlmid(stats_by_prefix, wlmid)
      zero = { photos_count: 0, quality_count: 0, featured_count: 0 }
      raw = wlmid.to_s.strip
      return zero if raw.empty? || stats_by_prefix.nil? || stats_by_prefix.empty?

      stats_by_prefix[pad_wlmid(raw)] || stats_by_prefix[raw] || zero
    end

    def fetch_gps_coordinates_for_monuments(monuments)
      return {} if monuments.blank?

      links_conn = commons_links_connection
      core_conn = commons_connection
      items_by_prefix = Hash.new { |h, k| h[k] = [] }
      items_by_category = Hash.new { |h, k| h[k] = [] }
      files_by_item = Hash.new { |h, k| h[k] = Set.new }

      monuments.each do |monument|
        item = extract_attr(monument, :item)
        next if item.blank?

        wlmid = extract_attr(monument, :wlmid).to_s.strip
        unless wlmid.empty?
          padded = pad_wlmid(wlmid)
          items_by_prefix[padded] << item
          items_by_prefix[wlmid] << item unless wlmid == padded
        end

        commons_cat = normalize_category_title(extract_attr(monument, :commons))
        items_by_category[commons_cat] << item unless commons_cat.empty?

        image_name = extract_attr(monument, :image)
        if image_name.present?
          decoded_image = decode_uri_component_safe(image_name.to_s)
          norm_file = normalize_file_title(decoded_image)
          files_by_item[item].add(norm_file) unless norm_file.empty?
        end
      end

      collect_wlm_files_by_prefix(links_conn, items_by_prefix, files_by_item)
      collect_category_files(links_conn, items_by_category, files_by_item)

      all_files = Set.new
      files_by_item.each_value { |file_set| all_files.merge(file_set) }
      return {} if all_files.empty?

      coords_by_file = fetch_file_gps_coordinates(core_conn, all_files.to_a)
      return {} if coords_by_file.empty?

      result = {}
      files_by_item.each do |item, file_set|
        coords = file_set.filter_map { |file_name| coords_by_file[file_name] }
        result[item] = coords unless coords.empty?
      end
      result
    end

    def extract_gps_from_metadata(raw_metadata)
      str = decode(raw_metadata)
      return nil if str.nil? || str.strip.empty?

      lat, lon = if str.lstrip.start_with?("{", "[")
                   extract_gps_from_json(str)
                 else
                   extract_gps_from_php_serialized(str)
                 end

      return nil if lat.nil? || lon.nil?

      lat_dec = to_big_decimal(lat)
      lon_dec = to_big_decimal(lon)
      return nil if lat_dec.nil? || lon_dec.nil? || lat_dec.zero? || lon_dec.zero?

      [lat_dec, lon_dec]
    end

    private

    def commons_connection
      CommonsReplicaRecord.connection
    end

    def commons_links_connection
      CommonsLinksReplicaRecord.connection
    end

    def extract_attr(obj, key)
      if obj.is_a?(Hash)
        obj[key] || obj[key.to_s]
      else
        obj.public_send(key)
      end
    end

    def decode_uri_component_safe(value)
      URI.decode_www_form_component(value)
    rescue ArgumentError
      value
    end

    def fetch_category_linktarget_ids(conn, titles)
      quoted = titles.map { |t| conn.quote(t) }.join(", ")
      sql = <<~SQL
        SELECT lt_id, lt_title
        FROM linktarget
        WHERE lt_namespace = 14
          AND lt_title IN (#{quoted})
      SQL

      ids = {}
      conn.select_all(sql).each do |row|
        ids[decode(row["lt_title"])] = row["lt_id"].to_i
      end
      ids
    end

    def category_filter_sql(conn, table_alias, normalized_category_title)
      quoted_cat = conn.quote(normalized_category_title)

      if categorylinks_uses_linktarget?
        join_sql = <<~SQL
          JOIN linktarget lt_#{table_alias}
            ON #{table_alias}.cl_target_id = lt_#{table_alias}.lt_id
           AND lt_#{table_alias}.lt_namespace = 14
           AND lt_#{table_alias}.lt_title = #{quoted_cat}
        SQL
        [join_sql, ""]
      else
        ["", "#{table_alias}.cl_to = #{quoted_cat}"]
      end
    end

    def collect_wlm_files_by_prefix(conn, items_by_prefix, files_by_item)
      prefixes = items_by_prefix.keys
      return if prefixes.empty?

      cat_join, cat_where = category_filter_sql(conn, "cl", KNOWN_IDS_CATEGORY)

      prefixes.each_slice(BATCH_SIZE) do |slice|
        quoted_prefixes = slice.map { |p| conn.quote(p) }.join(", ")
        conditions = [
          "cl.cl_type = 'file'",
          "cl.cl_sortkey_prefix IN (#{quoted_prefixes})"
        ]
        conditions << cat_where unless cat_where.empty?

        sql = <<~SQL
          SELECT
            cl.cl_sortkey_prefix AS sortkey_prefix,
            p.page_title AS page_title
          FROM categorylinks cl
          #{cat_join}
          JOIN page p
            ON p.page_id = cl.cl_from
           AND p.page_namespace = 6
          WHERE #{conditions.join(' AND ')}
        SQL

        conn.select_all(sql).each do |row|
          prefix = decode(row["sortkey_prefix"])&.strip
          file_title = decode(row["page_title"])
          next if prefix.nil? || file_title.nil? || file_title.empty?

          items_by_prefix[prefix].each { |item| files_by_item[item].add(file_title) }
        end
      end
    end

    def collect_category_files(conn, items_by_category, files_by_item)
      categories = items_by_category.keys
      return if categories.empty?

      categories.each_slice(BATCH_SIZE) do |slice|
        quoted_cats = slice.map { |c| conn.quote(c) }.join(", ")

        sql = if categorylinks_uses_linktarget?
                <<~SQL
                  SELECT
                    lt.lt_title AS cat_title,
                    p.page_title AS page_title
                  FROM linktarget lt
                  JOIN categorylinks cl
                    ON cl.cl_target_id = lt.lt_id
                  JOIN page p
                    ON p.page_id = cl.cl_from
                   AND p.page_namespace = 6
                  WHERE lt.lt_namespace = 14
                    AND lt.lt_title IN (#{quoted_cats})
                    AND cl.cl_type = 'file'
                SQL
              else
                <<~SQL
                  SELECT
                    cl.cl_to AS cat_title,
                    p.page_title AS page_title
                  FROM categorylinks cl
                  JOIN page p
                    ON p.page_id = cl.cl_from
                   AND p.page_namespace = 6
                  WHERE cl.cl_to IN (#{quoted_cats})
                    AND cl.cl_type = 'file'
                SQL
              end

        conn.select_all(sql).each do |row|
          cat_title = decode(row["cat_title"])
          file_title = decode(row["page_title"])
          next if cat_title.nil? || file_title.nil? || file_title.empty?

          items_by_category[cat_title].each { |item| files_by_item[item].add(file_title) }
        end
      end
    end

    def fetch_file_gps_coordinates(conn, file_names)
      coords_by_file = {}
      use_file_revision = uses_file_revision_tables?

      file_names.each_slice(METADATA_BATCH_SIZE) do |slice|
        quoted_files = slice.map { |f| conn.quote(f) }.join(", ")

        sql = if use_file_revision
                <<~SQL
                  SELECT
                    f.file_name AS file_name,
                    fr.fr_metadata AS metadata
                  FROM file f
                  JOIN filerevision fr
                    ON fr.fr_id = f.file_latest
                  WHERE f.file_name IN (#{quoted_files})
                SQL
              else
                <<~SQL
                  SELECT
                    img_name AS file_name,
                    img_metadata AS metadata
                  FROM image
                  WHERE img_name IN (#{quoted_files})
                SQL
              end

        conn.select_all(sql).each do |row|
          coords = extract_gps_from_metadata(row["metadata"])
          next if coords.nil?

          coords_by_file[decode(row["file_name"])] = coords
        end
      end

      coords_by_file
    end

    def extract_gps_from_json(json_str)
      parsed = JSON.parse(json_str)
      extract_gps_from_json_node(parsed)
    rescue JSON::ParserError
      nil
    end

    def extract_gps_from_json_node(node)
      case node
      when Hash
        if node.key?("GPSLatitude") && node.key?("GPSLongitude")
          return [node["GPSLatitude"], node["GPSLongitude"]]
        end
        return extract_gps_from_json_node(node["data"]) if node.key?("data")
      when Array
        lat_entry = node.find { |item| item.is_a?(Hash) && item["name"] == "GPSLatitude" }
        lon_entry = node.find { |item| item.is_a?(Hash) && item["name"] == "GPSLongitude" }
        return [lat_entry["value"], lon_entry["value"]] if lat_entry && lon_entry
      end
      nil
    end

    def extract_gps_from_php_serialized(str)
      lat_match = str.match(/"GPSLatitude";(?:d:([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|i:([+-]?\d+)|s:\d+:"([+-]?\d+(?:\.\d+)?)")/)
      lon_match = str.match(/"GPSLongitude";(?:d:([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|i:([+-]?\d+)|s:\d+:"([+-]?\d+(?:\.\d+)?)")/)
      return nil unless lat_match && lon_match

      lat = lat_match.captures.compact.first
      lon = lon_match.captures.compact.first
      [lat, lon]
    end

    def to_big_decimal(value)
      return nil if value.nil?

      BigDecimal(value.to_s.strip)
    rescue ArgumentError
      nil
    end
  end
end
