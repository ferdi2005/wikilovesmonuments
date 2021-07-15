require 'test_helper'

class TownsControllerTest < ActionDispatch::IntegrationTest
  test "should get search" do
    get towns_search_url
    assert_response :success
  end

end
