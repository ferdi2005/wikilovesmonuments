require 'test_helper'

class ImportControllerTest < ActionDispatch::IntegrationTest
  test "should get do" do
    get import_do_url
    assert_response :success
  end

end
