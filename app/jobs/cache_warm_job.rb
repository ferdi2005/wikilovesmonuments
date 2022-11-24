class CacheWarmJob < ApplicationJob
  queue_as :default

  def perform(*args)
    expire_page controller: "monuments", action: "map"

    MonumentsController.render("map")
  end
end
