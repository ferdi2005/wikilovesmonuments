# frozen_string_literal: true

module Api
  class LookupJob < ApplicationJob
    queue_as :default

    def perform(*_args)
      default_concurrency = (ENV["TOOLFORGE"].to_s.downcase == "true") ? 10 : 3
      concurrency = ENV.fetch("WIKIMEDIA_CONCURRENCY") { default_concurrency }.to_i
      thread_pool = Concurrent::FixedThreadPool.new(concurrency)

      Monument.find_each do |monument|
        thread_pool.post do
          search = %("#{monument.wlmid}")
          count = WikimediaApi.get(
            "https://commons.wikimedia.org/w/api.php",
            query: {
              action: :query,
              list: :search,
              srsearch: search,
              srwhat: :text,
              srnamespace: 6,
              srlimit: 1,
              format: :json
            }
          )
          totalhits = count.try(:[], "query").try(:[], "searchinfo").try(:[], "totalhits")

          if totalhits.nil?
            puts "Skipping ID: #{monument.id} - WLMID: #{monument.wlmid} - no response from Commons"
            next
          end

          quality_search = %("#{monument.wlmid}" incategory:"Quality images")
          quality_count = WikimediaApi.get(
            "https://commons.wikimedia.org/w/api.php",
            query: {
              action: :query,
              list: :search,
              srsearch: quality_search,
              srwhat: :text,
              srnamespace: 6,
              srlimit: 1,
              format: :json
            }
          )
          quality = quality_count.try(:[], "query").try(:[], "searchinfo").try(:[], "totalhits")

          featured_search = %("#{monument.wlmid}" incategory:"Featured pictures on Wikimedia_Commons")
          featured_count = WikimediaApi.get(
            "https://commons.wikimedia.org/w/api.php",
            query: {
              action: :query,
              list: :search,
              srsearch: featured_search,
              srwhat: :text,
              srnamespace: 6,
              srlimit: 1,
              format: :json
            }
          )
          featured = featured_count.try(:[], "query").try(:[], "searchinfo").try(:[], "totalhits")

          quality_bool = (quality&.> 0) ? true : false
          featured_bool = (featured&.> 0) ? true : false

          if totalhits > 0 || !monument.image.nil?
            monument.update!(
              with_photos: true,
              photos_count: totalhits,
              quality: quality_bool,
              featured: featured_bool,
              quality_count: quality,
              featured_count: featured
            )
          elsif !monument.commons.nil?
            begin
              category_res = WikimediaApi.get(
                "https://commons.wikimedia.org/w/api.php",
                query: {
                  action: :query,
                  prop: :categoryinfo,
                  titles: "Category:#{monument.commons}",
                  format: :json
                }
              )
              files = category_res.try(:[], "query").try(:[], "pages")&.values&.first.try(:[], "categoryinfo").try(:[], "files").to_i
              monument.update!(with_photos: files > 0, photos_count: totalhits, commonsphotos: files)
            rescue StandardError
              monument.update!(with_photos: false, photos_count: totalhits)
            end
          else
            monument.update!(with_photos: false, photos_count: totalhits)
          end

          puts "Processed monument with ID: #{monument.id} - WLMID: #{monument.wlmid}"
        end
      end

      thread_pool.shutdown
      thread_pool.wait_for_termination
    end
  end
end
