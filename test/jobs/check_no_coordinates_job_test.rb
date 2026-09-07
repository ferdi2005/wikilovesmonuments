require "test_helper"
require "minitest/mock"

class CheckNoCoordinatesJobTest < ActiveJob::TestCase
  test "CheckNoCoordinatesJob elabora monumenti senza coordinate" do
    monument = monuments(:one)
    monument.update!(latitude: nil, photos_count: 5)

    fake_response = {
      'query' => {
        'pages' => {}
      }
    }

    WikimediaApi.stub(:get, fake_response) do
      assert_nothing_raised do
        CheckNoCoordinatesJob.perform_now
      end
    end
  end
end
