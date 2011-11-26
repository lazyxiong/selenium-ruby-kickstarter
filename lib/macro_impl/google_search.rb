class GoogleSearchMacro

    def initialize(suite)
       @suite = suite
       @suite.set_test_name(self.class.name)
    end

    # -- test begins
    def run_test
       @suite.p("-- google macro...")
       @suite.selenium.open(@suite.proper_base_url("/"))
       @suite.wait_for_page_and_verify_text("Google")
       @suite.type("q", @suite.common['quote'])
       @suite.click("btnG")
       sleep 3
       @suite.check_page_and_verify_text(@suite.common['result'])
       # -- because now Google uses Ajax, we can't use 'wait_for_page' method
       #@suite.wait_for_page_and_verify_text(@suite.common['result'])
    end
end
