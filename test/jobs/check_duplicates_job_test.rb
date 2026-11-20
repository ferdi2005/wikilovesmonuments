require "test_helper"

class CheckDuplicatesJobTest < ActiveJob::TestCase
  test "CheckDuplicatesJob identifica correttamente i wlmid duplicati" do
    mon_one = monuments(:one)
    mon_two = monuments(:two)
    mon_one.update!(wlmid: "DUP001", duplicate: false)
    mon_two.update!(wlmid: "DUP001", duplicate: false)

    unique_mon = Monument.create!(item: "Q9999", wlmid: "UNIQ001", duplicate: true)

    CheckDuplicatesJob.perform_now

    assert_equal true, mon_one.reload.duplicate
    assert_equal true, mon_two.reload.duplicate
    assert_equal false, unique_mon.reload.duplicate
  end
end
