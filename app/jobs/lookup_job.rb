# frozen_string_literal: true

class LookupJob < ApplicationJob
  queue_as :default

  REGIONI = [
    "Abruzzo",
    "Basilicata",
    "Calabria",
    "Campania",
    "Emilia-Romagna",
    "Friuli-Venezia Giulia",
    "Lazio",
    "Liguria",
    "Lombardia",
    "Marche",
    "Molise",
    "Piemonte",
    "Puglia",
    "Sardegna",
    "Sicilia",
    "Toscana",
    "Trentino-Alto Adige",
    "Umbria",
    "Valle d'Aosta",
    "Veneto"
  ].freeze

  def perform(*args)
    puts "Starting to perform LookupJob..."

    if WikimediaReplicaClient.enabled?
      perform_with_replicas
    else
      Api::LookupJob.new.perform(*args)
    end

    if Monument.where("latitude IS NULL AND (photos_count > 0 OR with_photos = ?)", true).exists?
      CheckNoCoordinatesJob.perform_now
    end

    record_daily_nophoto_stats!
    CacheWarmJob.perform_later
  end

  private

  def perform_with_replicas
    wlm_stats = WikimediaReplicaClient.fetch_wlm_photo_stats
    commons_categories = Monument.where.not(commons: [nil, ""]).distinct.pluck(:commons)
    category_counts = WikimediaReplicaClient.fetch_category_files_counts(commons_categories)
    now = Time.current

    Monument.find_in_batches(batch_size: 2000) do |batch|
      records = batch.map do |monument|
        stats = WikimediaReplicaClient.lookup_stats_for_wlmid(wlm_stats, monument.wlmid)
        totalhits = stats[:photos_count]
        quality = stats[:quality_count]
        featured = stats[:featured_count]
        cat_files = if monument.commons.present?
                      category_counts[WikimediaReplicaClient.normalize_category_title(monument.commons)] || 0
                    end

        with_photos = (totalhits > 0) || !monument.image.nil? || (cat_files.to_i > 0)

        {
          id: monument.id,
          with_photos: with_photos,
          photos_count: totalhits,
          quality: quality > 0,
          featured: featured > 0,
          quality_count: quality,
          featured_count: featured,
          commonsphotos: cat_files,
          created_at: monument.created_at || now,
          updated_at: now
        }
      end

      next if records.empty?

      if Monument.connection.supports_insert_conflict_target?
        Monument.upsert_all(records, unique_by: :id)
      else
        Monument.upsert_all(records)
      end
    end
  end

  def record_daily_nophoto_stats!
    return if Nophoto.where(created_at: Date.today.to_datetime..DateTime.now).any?

    conn = Monument.connection
    q_true = conn.quoted_true
    q_false = conn.quoted_false

    global_sql = <<~SQL
      SELECT
        COUNT(*) AS monuments_count,
        SUM(CASE WHEN with_photos = #{q_false} THEN 1 ELSE 0 END) AS nophoto_count,
        SUM(CASE WHEN commons IS NOT NULL THEN 1 ELSE 0 END) AS with_commons_count,
        SUM(CASE WHEN image IS NOT NULL THEN 1 ELSE 0 END) AS with_image_count,
        SUM(CASE WHEN with_photos = #{q_true} AND photos_count = 0 THEN 1 ELSE 0 END) AS nowlm_count,
        COUNT(DISTINCT CASE WHEN tree = #{q_false} THEN city END) AS cities_count,
        COUNT(DISTINCT city) AS cities_with_trees_count
      FROM monuments
    SQL

    global_row = conn.select_one(global_sql) || {}
    Nophoto.create!(
      count: global_row["nophoto_count"].to_i,
      monuments: global_row["monuments_count"].to_i,
      with_commons: global_row["with_commons_count"].to_i,
      with_image: global_row["with_image_count"].to_i,
      nowlm: global_row["nowlm_count"].to_i,
      cities: global_row["cities_count"].to_i,
      cities_with_trees: global_row["cities_with_trees_count"].to_i
    )

    regional_sql = <<~SQL
      SELECT
        regione,
        COUNT(*) AS monuments_count,
        SUM(CASE WHEN with_photos = #{q_false} THEN 1 ELSE 0 END) AS nophoto_count,
        SUM(CASE WHEN commons IS NOT NULL THEN 1 ELSE 0 END) AS with_commons_count,
        SUM(CASE WHEN image IS NOT NULL THEN 1 ELSE 0 END) AS with_image_count,
        SUM(CASE WHEN with_photos = #{q_true} AND photos_count = 0 THEN 1 ELSE 0 END) AS nowlm_count,
        COUNT(DISTINCT CASE WHEN tree = #{q_false} THEN city END) AS cities_count,
        COUNT(DISTINCT city) AS cities_with_trees_count
      FROM monuments
      WHERE regione IS NOT NULL
      GROUP BY regione
    SQL

    by_region = conn.select_all(regional_sql).each_with_object({}) do |row, hash|
      hash[row["regione"]] = row
    end

    REGIONI.each do |reg|
      row = by_region[reg] || {}
      Nophoto.create!(
        regione: reg,
        count: row["nophoto_count"].to_i,
        monuments: row["monuments_count"].to_i,
        with_commons: row["with_commons_count"].to_i,
        with_image: row["with_image_count"].to_i,
        nowlm: row["nowlm_count"].to_i,
        cities: row["cities_count"].to_i,
        cities_with_trees: row["cities_with_trees_count"].to_i
      )
    end
  end
end
