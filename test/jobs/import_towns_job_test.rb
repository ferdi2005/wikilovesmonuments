require "test_helper"
require "minitest/mock"

class ImportTownsJobTest < ActiveJob::TestCase
  test "ImportTownsJob importa comuni IT ed EN da singola query SPARQL" do
    fake_bindings = [
      {
        "item" => { "value" => "http://www.wikidata.org/entity/Q3519" },
        "itemLabelIt" => { "value" => "Bari" },
        "townLabelIt" => { "value" => "città metropolitana di Bari" },
        "itemLabelEn" => { "value" => "Bari" },
        "townLabelEn" => { "value" => "Metropolitan City of Bari" },
        "commons" => { "value" => "Bari" },
        "coords" => { "value" => "Point(16.8719 41.1171)" }
      },
      {
        "item" => { "value" => "http://www.wikidata.org/entity/Q220" },
        "itemLabelIt" => { "value" => "Roma" },
        "commons" => { "value" => "Rome" }
      }
    ]

    WikidataSparqlClient.stub(:query, fake_bindings) do
      ImportTownsJob.perform_now
    end

    assert_equal 2, Town.count

    bari = Town.find_by!(item: "Q3519")
    assert_equal "Bari", bari.name
    assert_equal "Bari", bari.disambiguation
    assert_equal "Bari (Bari)", bari.visible_name
    assert_equal "Bari, Bari", bari.search_name
    assert_equal "Bari (Metropolitan City of Bari)", bari.english_name
    assert_equal "Bari", bari.commons
    assert_in_delta 41.1171, bari.latitude.to_f, 0.0001
    assert_in_delta 16.8719, bari.longitude.to_f, 0.0001

    roma = Town.find_by!(item: "Q220")
    assert_equal "Roma", roma.visible_name
    assert_equal "Roma", roma.english_name
  end
end
