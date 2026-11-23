require "test_helper"

class AnalyticsEndpointTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "monuments analytics_endpoint returns monument and town population fields" do
    Town.create!(item: "Q1001", name: "Comune Test", disambiguation: "BA", visible_name: "Comune Test (BA)", search_name: "Comune Test, BA", population: 3200)
    Monument.create!(
      item: "Q2001",
      wlmid: "16A0010001",
      itemlabel: "Chiesa Test",
      regione: "Puglia",
      city: "Comune Test",
      city_item: "Q1001",
      monument_type: "chiesa",
      instanceof_qid: "Q16970",
      inception_year: 1965,
      mic_catalog_id: "1600999999",
      wikipedia: "https://it.wikipedia.org/wiki/Chiesa_Test",
      commons: "Chiesa Test",
      image: "Chiesa_Test.jpg",
      photos_count: 3,
      commonsphotos: 5,
      hidden: false
    )

    get "/monuments/analytics_endpoint.json"
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 1, data.size
    row = data.first
    assert_equal "Q2001", row["item"]
    assert_equal "16A0010001", row["wlmid"]
    assert_equal 3200, row["municipality_population"]
    assert_equal "chiesa", row["monument_type"]
    assert_equal 1965, row["inception_year"]
    assert_equal "1600999999", row["mic_catalog_id"]
    assert_equal true, row["has_wikipedia"]
    assert_equal true, row["has_commons_category"]
    assert_equal true, row["has_p18"]
  end
end
