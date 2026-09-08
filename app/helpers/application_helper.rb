module ApplicationHelper
  def toolforge?
    ENV["TOOLFORGE"].to_s.downcase == "true"
  end
end
