
class LookupJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Monument.all.each do |monument|
      search = '"' + monument.wlmid + '"'
      count = HTTParty.get("https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=#{search}&srwhat=text&srnamespace=6&srlimit=1&format=json", uri_adapter: Addressable::URI).to_a
      if (count[1][0] == "continue")
        totalhits = count[2][1]['searchinfo']['totalhits']
      else
        totalhits = count[1][1]['searchinfo']['totalhits']
      end
      puts totalhits
      if (totalhits > 0)
        monument.update_attributes(with_photos: true, photos_count: totalhits)
      else
        monument.update_attributes(with_photos: false, photos_count: totalhits)
      end
    end
  end
end
