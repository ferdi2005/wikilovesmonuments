require "test_helper"
require "minitest/mock"

class CreateUrlJobTest < ActiveJob::TestCase
  test "createurl aggiorna correttamente uploadurl e nonwlmuploadurl" do
    monument = monuments(:one)
    monument.update!(regione: "Lazio", wlmid: "01A001")

    job = CreateUrlJob.new
    job.createurl(monument)

    monument.reload
    assert_includes monument.uploadurl, "+-+Lazio"
    assert_includes monument.uploadurl, "campaign=wlm-it"
    assert_not_includes monument.nonwlmuploadurl, "campaign=wlm-it"
    assert_not_includes monument.nonwlmuploadurl, "id=01A001"
  end

  test "createurl gestisce wlmid assente senza errori" do
    monument = monuments(:one)
    monument.update!(regione: "Lazio", wlmid: nil)

    job = CreateUrlJob.new
    assert_nothing_raised do
      job.createurl(monument)
    end
  end

  test "createurl ignora monumenti con regione non valida o nil senza errori" do
    monument = monuments(:one)
    monument.update!(regione: nil)

    job = CreateUrlJob.new
    assert_nothing_raised do
      job.createurl(monument)
    end
  end

  test "UploadUrlBuilder gestisce castelli, alberi, edifici religiosi e concorsi subregionali" do
    urls = UploadUrlBuilder.build_urls(
      {
        item: "Q123",
        wlmid: "16A6620001",
        itemlabel: "Castello (prova)",
        latitude: BigDecimal("41.12"),
        longitude: BigDecimal("16.87"),
        commons: nil,
        regione: "Campania",
        city_item: "Q55007",
        tree: true,
        is_castle: true
      },
      year: 2026,
      fallback_commons: "Ariano Irpino",
      religious: true
    )

    assert_includes urls[:uploadurl], "Ariano+Irpino"
    assert_includes urls[:uploadurl], "veteran+trees"
    assert_includes urls[:uploadurl], "religious+buildings"
    assert_includes urls[:uploadurl], "Campania+-+fortifications"
    assert_includes urls[:uploadurl], "Terre+dell%27Ufita"
    assert_not_includes urls[:uploadurl], "without+local+award"
    assert_includes urls[:uploadurl], "%28prova%29"
    assert_includes urls[:uploadurl], "lat=41.12"
    assert_includes urls[:nonwlmuploadurl], "categories=Ariano+Irpino"
    assert_not_includes urls[:nonwlmuploadurl], "Wiki+Loves+Monuments"
  end
end
