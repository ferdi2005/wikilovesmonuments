require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "should get imagematch" do
    get games_imagematch_url
    assert_response :success
  end

  test "should get categorymatch" do
    get games_categorymatch_url
    assert_response :success
  end

  test "should get articlematch" do
    get games_articlematch_url
    assert_response :success
  end
end
