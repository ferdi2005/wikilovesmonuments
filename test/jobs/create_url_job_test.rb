require 'test_helper'
require 'minitest/mock'

class CreateUrlJobTest < ActiveJob::TestCase
  test "createurl aggiorna correttamente uploadurl e nonwlmuploadurl" do
    monument = monuments(:one)
    monument.update!(regione: "Lazio", wlmid: "01A001")

    fake_response = {
      "expandtemplates" => {
        "wikitext" => "https://commons.wikimedia.org/wiki/Special:UploadWizard?id=01A001&campaign=wlm-it&categories=Images+from+Wiki+Loves+Monuments+2023+in+Italy+-+unknown+region"
      }
    }

    job = CreateUrlJob.new
    WikimediaApi.stub(:get, fake_response) do
      job.createurl(monument)
    end

    monument.reload
    assert_includes monument.uploadurl, "+-+Lazio"
    assert_includes monument.uploadurl, "campaign=wlm-it"
    assert_not_includes monument.nonwlmuploadurl, "campaign=wlm-it"
  end

  test "createurl gestisce risposte vuote o nil senza errori" do
    monument = monuments(:one)
    monument.update!(regione: "Lazio")

    job = CreateUrlJob.new
    WikimediaApi.stub(:get, nil) do
      assert_nothing_raised do
        job.createurl(monument)
      end
    end

    WikimediaApi.stub(:get, { "expandtemplates" => { "wikitext" => "" } }) do
      assert_nothing_raised do
        job.createurl(monument)
      end
    end
  end

  test "createurl ignora monumenti con regione non valida o nil senza errori" do
    monument = monuments(:one)
    monument.update!(regione: nil)

    fake_response = {
      "expandtemplates" => {
        "wikitext" => "https://commons.wikimedia.org/wiki/Special:UploadWizard?id=01A001"
      }
    }

    job = CreateUrlJob.new
    WikimediaApi.stub(:get, fake_response) do
      assert_nothing_raised do
        job.createurl(monument)
      end
    end
  end
end
