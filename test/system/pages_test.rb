require "application_system_test_case"

class PagesTest < ApplicationSystemTestCase
  test "about page loads" do
    visit about_path

    assert_text "About"
    assert_text "Images are interpretive"
  end
end
