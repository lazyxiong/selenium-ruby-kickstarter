class GoogleSearchMacro

    def initialize(suite)
       @suite = suite
       @suite.set_test_name(self.class.name)
    end

    # -- test begins
    def run_test
       @suite.p("-- google macro...")
       @suite.navigate(@suite.create_url("/"))
       @suite.wait_for_text("Google")
       @suite.type("q", @suite.common['quote'])
       @suite.click("btnG")
       @suite.wait_for_text(@suite.common['result'])
    end
end
