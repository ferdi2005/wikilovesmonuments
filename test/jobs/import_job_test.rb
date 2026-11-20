require "test_helper"
require "minitest/mock"

class ImportJobTest < ActiveJob::TestCase
  test "ImportJob importa da SPARQL, calcola duplicati e URL di upload localmente" do
    main_bindings = [
      {
        "item" => { "value" => "http://www.wikidata.org/entity/Q1001" },
        "wlmid" => { "value" => "03M0010001" },
        "itemLabel" => { "value" => "Villa del Lago" },
        "coords" => { "value" => "Point(9.25 45.81)" },
        "regione" => { "value" => "http://www.wikidata.org/entity/Q1210" },
        "unit" => { "value" => "http://www.wikidata.org/entity/Q1234" },
        "unitLabel" => { "value" => "Como" },
        "unitCommons" => { "value" => "Como" },
        "religiousSponsor" => { "value" => "http://www.wikidata.org/entity/Q1" }
      },
      {
        "item" => { "value" => "http://www.wikidata.org/entity/Q1002" },
        "wlmid" => { "value" => "03M0010001" },
        "itemLabel" => { "value" => "Altro monumento" },
        "coords" => { "value" => "Point(9.26 45.82)" },
        "regione" => { "value" => "http://www.wikidata.org/entity/Q1210" },
        "unit" => { "value" => "http://www.wikidata.org/entity/Q1234" },
        "unitLabel" => { "value" => "Como" }
      }
    ]

    lakecomo_bindings = [
      { "item" => { "value" => "http://www.wikidata.org/entity/Q1001" } }
    ]

    stub_query = lambda do |sparql|
      sparql.include?("Q16161") ? lakecomo_bindings : main_bindings
    end

    WikidataSparqlClient.stub(:query, stub_query) do
      ImportJob.perform_now
    end

    assert_nil Monument.find_by(item: "MyString")

    m1 = Monument.find_by!(item: "Q1001")
    m2 = Monument.find_by!(item: "Q1002")

    assert_equal true, m1.duplicate
    assert_equal true, m2.duplicate
    assert_equal "Lombardia", m1.regione
    assert_includes m1.uploadurl, "Lake+Como"
    assert_includes m1.uploadurl, "religious+buildings"
    assert_includes m1.uploadurl, "categories=Como"
    assert_not_includes m1.nonwlmuploadurl, "campaign=wlm-it"
  end
end
