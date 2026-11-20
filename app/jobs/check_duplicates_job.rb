# frozen_string_literal: true

class CheckDuplicatesJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    Monument.where(duplicate: true).update_all(duplicate: false)
    duplicate_wlmids = Monument.where.not(wlmid: [nil, ""])
                               .group(:wlmid)
                               .having("COUNT(*) > 1")
                               .pluck(:wlmid)
    Monument.where(wlmid: duplicate_wlmids).update_all(duplicate: true) if duplicate_wlmids.any?
  end
end
