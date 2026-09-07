require 'test_helper'
require 'minitest/mock'

class LookupJobTest < ActiveJob::TestCase
  test "LookupJob elabora monumenti invocando WikimediaApi" do
    monument = monuments(:one)

    fake_response = {
      'query' => {
        'searchinfo' => {
          'totalhits' => 3
        }
      }
    }

    WikimediaApi.stub(:get, fake_response) do
      LookupJob.perform_now
    end

    monument.reload
    assert_equal 3, monument.photos_count
    assert_equal true, monument.with_photos
  end
end
