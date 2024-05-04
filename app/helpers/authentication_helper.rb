module AuthenticationHelper
    $oauth_consumer = OAuth::Consumer.new(ENV["CONSUMER_KEY"], ENV["CONSUMER_SECRET"], :site => "https://www.wikidata.org", :request_token_path => "/w/index.php?title=Special:OAuth/initiate", :authorize_path => "/wiki/Special:OAuth/authorize", :access_token_path => "/wiki/Special:OAuth/token",)

    $wikidata_oauth_consumer = OAuth::Consumer.new(ENV["CONSUMER_KEY"], ENV["CONSUMER_SECRET"], :site => "https://www.wikidata.org", :request_token_path => "/w/index.php?title=Special:OAuth/initiate", :authorize_path => "/wiki/Special:OAuth/authorize", :access_token_path => "/wiki/Special:OAuth/token",)

    $commons_oauth_consumer = OAuth::Consumer.new(ENV["CONSUMER_KEY"], ENV["CONSUMER_SECRET"], :site => "https://commons.wikimedia.org", :request_token_path => "/w/index.php?title=Special:OAuth/initiate", :authorize_path => "/wiki/Special:OAuth/authorize", :access_token_path => "/wiki/Special:OAuth/token",)

    # Sempre mettere lo / davanti
end
