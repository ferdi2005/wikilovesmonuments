class CheckDuplicatesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    duplicati = Monument.pluck(:id, :wlmid).group_by { |m| m[1] }.delete_if { |_, k| k.count == 1 }
    to_be_updated = {}
    Monument.update_all(duplicate: false)
    duplicati.each { |_, d| d.each { |t| to_be_updated[t[0]] = {"duplicate": true } }}
    Monument.update(to_be_updated.keys, to_be_updated.values)
  end
end