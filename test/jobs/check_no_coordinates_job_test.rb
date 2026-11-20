require "test_helper"
require "minitest/mock"

class CheckNoCoordinatesJobTest < ActiveJob::TestCase
  test "CheckNoCoordinatesJob elabora monumenti senza coordinate via API" do
    monument = monuments(:one)
    monument.update!(latitude: nil, photos_count: 5)

    fake_response = {
      "query" => {
        "pages" => {}
      }
    }

    WikimediaReplicaClient.stub(:enabled?, false) do
      WikimediaApi.stub(:get, fake_response) do
        assert_nothing_raised do
          CheckNoCoordinatesJob.perform_now
        end
      end
    end
  end

  test "CheckNoCoordinatesJob calcola coordinate presunte via API" do
    monument = monuments(:one)
    monument.update!(latitude: nil, longitude: nil, photos_count: 2, commons: nil, image: nil)

    fake_response = {
      "query" => {
        "pages" => {
          "100" => {
            "ns" => 6,
            "imageinfo" => [
              {
                "metadata" => [
                  { "name" => "GPSLatitude", "value" => 41.9 },
                  { "name" => "GPSLongitude", "value" => 12.5 }
                ]
              }
            ]
          }
        }
      }
    }

    WikimediaReplicaClient.stub(:enabled?, false) do
      WikimediaApi.stub(:get, fake_response) do
        CheckNoCoordinatesJob.perform_now
      end
    end

    monument.reload
    assert_in_delta 41.9, monument.presumed_latitude.to_f, 0.001
    assert_in_delta 12.5, monument.presumed_longitude.to_f, 0.001
  end

  test "CheckNoCoordinatesJob usa la replica Toolforge quando abilitata" do
    monument = monuments(:one)
    monument.update!(latitude: nil, longitude: nil, photos_count: 2, with_photos: true)

    fake_coords = {
      monument.item => [
        [BigDecimal("41.10"), BigDecimal("16.80")],
        [BigDecimal("41.20"), BigDecimal("16.90")]
      ]
    }

    WikimediaReplicaClient.stub(:enabled?, true) do
      WikimediaReplicaClient.stub(:fetch_gps_coordinates_for_monuments, fake_coords) do
        CheckNoCoordinatesJob.perform_now
      end
    end

    monument.reload
    assert_in_delta 41.2, monument.presumed_maxlat.to_f, 0.001
    assert_in_delta 41.1, monument.presumed_minlat.to_f, 0.001
    assert_in_delta 16.9, monument.presumed_maxlon.to_f, 0.001
    assert_in_delta 16.8, monument.presumed_minlon.to_f, 0.001
    assert_not_nil monument.presumed_latitude
    assert_not_nil monument.presumed_longitude
  end

  test "WikimediaReplicaClient estrae coordinate GPS da metadata JSON e PHP serialized" do
    json_top = '{"GPSLatitude":41.8902,"GPSLongitude":12.4922}'
    assert_equal [BigDecimal("41.8902"), BigDecimal("12.4922")],
                 WikimediaReplicaClient.extract_gps_from_metadata(json_top)

    json_mw = '{"data":{"GPSLatitude":"45.4642","GPSLongitude":"9.1900"},"_type":"fs"}'
    assert_equal [BigDecimal("45.4642"), BigDecimal("9.1900")],
                 WikimediaReplicaClient.extract_gps_from_metadata(json_mw)

    php_serialized = 'a:2:{s:11:"GPSLatitude";d:40.8518;s:12:"GPSLongitude";s:7:"14.2681";}'
    assert_equal [BigDecimal("40.8518"), BigDecimal("14.2681")],
                 WikimediaReplicaClient.extract_gps_from_metadata(php_serialized)

    zero_coords = '{"GPSLatitude":0,"GPSLongitude":0}'
    assert_nil WikimediaReplicaClient.extract_gps_from_metadata(zero_coords)
  end

  test "WikimediaReplicaClient separa le query tra cluster links x4 e cluster core s4" do
    links_queries = []
    core_queries = []

    fake_links_conn = Object.new
    fake_links_conn.define_singleton_method(:quote) { |val| "'#{val}'" }
    fake_links_conn.define_singleton_method(:column_exists?) { |_table, _col| true }
    fake_links_conn.define_singleton_method(:select_all) do |sql|
      links_queries << sql
      if sql.include?("FROM categorylinks")
        [{ "sortkey_prefix" => "16A6620001", "page_title" => "Bari_test.jpg" }]
      else
        []
      end
    end

    fake_core_conn = Object.new
    fake_core_conn.define_singleton_method(:quote) { |val| "'#{val}'" }
    fake_core_conn.define_singleton_method(:data_source_exists?) { |_table| true }
    fake_core_conn.define_singleton_method(:select_all) do |sql|
      core_queries << sql
      [{ "file_name" => "Bari_test.jpg", "metadata" => '{"GPSLatitude":41.12,"GPSLongitude":16.87}' }]
    end

    monument = monuments(:one)
    monument.update!(item: "Q16A", wlmid: "16A6620001", commons: nil, image: nil)

    WikimediaReplicaClient.reset_schema_cache!
    CommonsLinksReplicaRecord.stub(:connection, fake_links_conn) do
      CommonsReplicaRecord.stub(:connection, fake_core_conn) do
        result = WikimediaReplicaClient.fetch_gps_coordinates_for_monuments([monument])
        assert_equal({ "Q16A" => [[BigDecimal("41.12"), BigDecimal("16.87")]] }, result)
      end
    end
  ensure
    WikimediaReplicaClient.reset_schema_cache!
    assert_not_empty links_queries
    assert_not_empty core_queries
    assert links_queries.all? { |sql| !sql.include?("filerevision") && !sql.match?(/\bFROM\s+category\b/) }
    assert core_queries.all? { |sql| sql.include?("filerevision") && !sql.include?("categorylinks") && !sql.include?("linktarget") }
  end
end
