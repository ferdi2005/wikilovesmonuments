class CommonsReplicaRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection :commons_replica if !Rails.env.test? || ENV["USE_TOOLFORGE_REPLICAS"].to_s.downcase == "true"

  def readonly?
    true
  end
end
