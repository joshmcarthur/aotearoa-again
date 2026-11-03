require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Public pages send cacheable headers; stop Chrome reusing one test's
  # response in the next.
  setup do
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: true)
  end
end
