require "application_system_test_case"

class EditionsTest < ApplicationSystemTestCase
  test "today page loads when no edition is published" do
    visit root_path

    assert_text "Next plate soon"
    assert_text "Aotearoa, Again"
  end
end
