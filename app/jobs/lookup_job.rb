# frozen_string_literal: true

class LookupJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    Monument.where(image: nil, commons: nil).each do |monument|
      search = '"' + monument.wlmid + '"'
      retimes = 0
      begin
        count = HTTParty.get("https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=#{search}&srwhat=text&srnamespace=6&srlimit=1&format=json",
                             headers: { 'User-Agent' => 'WikiLovesMonumentsItaly MonumentsFinder/1.4 (https://github.com/ferdi2005/wikilovesmonuments; ferdi.traversa@gmail.com) using HTTParty Ruby Gem' },
                             uri_adapter: Addressable::URI).to_a
      rescue StandardError
        retimes += 1
        if retimes < 4
          puts "Retrying for ID: #{monument.id} - WLMID: #{monument.wlmid}"
          retry
        else
          puts "Skipping ID: #{monument.id} - WLMID: #{monument.wlmid}"
          next
        end
      end
      totalhits = if count[1][0] == 'continue'
                    count[2][1]['searchinfo']['totalhits']
                  else
                    count[1][1]['searchinfo']['totalhits']
                  end
      if totalhits > 0
        monument.update_attributes(with_photos: true, photos_count: totalhits)
      else
        monument.update_attributes(with_photos: false, photos_count: totalhits)
      end
    end

    nophoto = Monument.where(with_photos: false).count
    Nophoto.create(count: nophoto, monuments: Monument.count)
  end
end
