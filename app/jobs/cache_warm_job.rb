class CacheWarmJob < ApplicationJob
  queue_as :default

  def perform(*args)
    MonumentsController.expire_page("map")

    MonumentsController.render("map")
  end
end
