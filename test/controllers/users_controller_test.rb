require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get get" do
    get users_get_url
    assert_response :success
  end

  test "should get destroy" do
    get users_destroy_url
    assert_response :success
  end

end
