#!/usr/bin/env ruby
require 'lib/base_test'

# @author Alexandre Berman
# @executeArgs
# @keywords acceptance
# @description test to demo google search

class GoogleSearchTest < BaseTest

   # -- initialize
    def initialize
       super
    end

   # -- test begins
    def run_main
       GoogleSearchMacro.new(suite).run_test
    end
end

GoogleSearchTest.new.run_test
