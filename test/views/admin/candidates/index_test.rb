require "test_helper"

module Admin
  class CandidatesIndexViewTest < ActionView::TestCase
    helper Admin::CandidatesHelper

    test "renders harvest candidates button" do
      @runway_days = 0
      @pending = 0
      @candidates = Candidate.none

      render template: "admin/candidates/index"

      assert_select "form[action=?]", harvest_admin_candidates_path do
        assert_select "button[type=submit]", text: "Harvest candidates"
      end
    end
  end
end
