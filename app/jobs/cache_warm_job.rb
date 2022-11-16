class CacheWarmJob < ApplicationJob
  queue_as :default

  def perform(*args)
    ApplicationController.render(
      :partial => 'monuments/monument',
      :collection => Monument.where(hidden: false),
      :cached => true
    )
  end
end
