class CheckDuplicatesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Monument.all.each do |mon|
      if Monument.where(wlmid: mon.wlmid).count > 1
        mon.update(duplicate: true)
      else
        mon.update(duplicate: false)
      end
    end
  end
end
