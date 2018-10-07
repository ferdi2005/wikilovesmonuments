require 'test_helper'

class MonumentsControllerTest < ActionDispatch::IntegrationTest
  test "should get list" do
    get monuments_list_url
    assert_response :success
  end

  test "should get show" do
    get monuments_show_url
    assert_response :success
  end

end
