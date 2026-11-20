require "test_helper"
require "minitest/mock"

class LookupJobTest < ActiveJob::TestCase
  test "LookupJob elabora monumenti invocando WikimediaApi in fallback" do
    monument = monuments(:one)

    fake_response = {
      "query" => {
        "searchinfo" => {
          "totalhits" => 3
        }
      }
    }

    WikimediaReplicaClient.stub(:enabled?, false) do
      WikimediaApi.stub(:get, fake_response) do
        LookupJob.perform_now
      end
    end

    monument.reload
    assert_equal 3, monument.photos_count
    assert_equal true, monument.with_photos
  end

  test "LookupJob usa la replica Toolforge quando abilitata e aggiorna coordinate e Nophoto" do
    Nophoto.delete_all
    mon_one = monuments(:one)
    mon_one.update!(wlmid: "16A6620001", commons: "Teatro Petruzzelli", image: nil, latitude: 41.1, longitude: 16.8)

    mon_two = monuments(:two)
    mon_two.update!(wlmid: "01A001", commons: nil, image: nil, latitude: nil, longitude: nil)

    fake_stats = {
      "16A6620001" => { photos_count: 12, quality_count: 2, featured_count: 1 },
      "000001A001" => { photos_count: 4, quality_count: 0, featured_count: 0 }
    }
    fake_cat_counts = { "Teatro_Petruzzelli" => 25 }
    fake_gps = { mon_two.item => [[BigDecimal("41.9"), BigDecimal("12.5")]] }

    WikimediaReplicaClient.stub(:enabled?, true) do
      WikimediaReplicaClient.stub(:fetch_wlm_photo_stats, fake_stats) do
        WikimediaReplicaClient.stub(:fetch_category_files_counts, fake_cat_counts) do
          WikimediaReplicaClient.stub(:fetch_gps_coordinates_for_monuments, fake_gps) do
            LookupJob.perform_now
          end
        end
      end
    end

    mon_one.reload
    assert_equal 12, mon_one.photos_count
    assert_equal true, mon_one.with_photos
    assert_equal true, mon_one.quality
    assert_equal 2, mon_one.quality_count
    assert_equal true, mon_one.featured
    assert_equal 1, mon_one.featured_count
    assert_equal 25, mon_one.commonsphotos

    mon_two.reload
    assert_equal 4, mon_two.photos_count
    assert_equal true, mon_two.with_photos
    assert_in_delta 41.9, mon_two.presumed_latitude.to_f, 0.001
    assert_in_delta 12.5, mon_two.presumed_longitude.to_f, 0.001

    assert_equal 21, Nophoto.where(created_at: Date.today.to_datetime..DateTime.now).count
  end
end
