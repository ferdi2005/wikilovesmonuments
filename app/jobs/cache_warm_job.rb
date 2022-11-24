class CacheWarmJob < ApplicationJob
  queue_as :default

  def perform(*args)
    MonumentsController.expire_page("map")

    app.get("/map")
  end
end
