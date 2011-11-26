#!/usr/bin/env ruby
require 'lib/base_test'

# @author Alexandre Berman
# @executeArgs
# @keywords tofail
# @description test to demonstrate failure

class GoogleSearchTofailTest < BaseTest

   # -- initialize
    def initialize
       super
    end

   # -- test begins
    def run_main
       @suite.common['result'] = "xxx"
       GoogleSearchMacro.new(suite).run_test
    end
end

GoogleSearchTofailTest.new.run_test
