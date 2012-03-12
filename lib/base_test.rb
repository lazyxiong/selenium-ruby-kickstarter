#!/usr/bin/env ruby
#    Copyright (C) 2009 Alexandre Berman, Lazybear Consulting (sashka@lazybear.net)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
require 'lib/ruby_suite'

class BaseTest
    attr_accessor :suite, :passed, :keyword
    def initialize
       @suite   = RubySuite.new(:test_name => self.class.name)
       @passed  = false
       @keyword = get_keyword
    end

    # -- test begins
    def run_test
       begin
          setup
          run_main
          @passed = true
       rescue => e
          @suite.p "FAILED: "
          @suite.p e.inspect
          @suite.p e.backtrace
          save_screenshot if ENV['REPORTS_DIR']
       ensure
          teardown
          @suite.clean_exit(@passed)
       end
    end

    # -- save screenshots to REPORTS_DIR
    def save_screenshot
      @suite.p "-- CAPTURE SCREENSHOT ::"
      begin
        screenshot_flag = true
        filename = (ENV['REPORTS_DIR'] + "/" + self.class.name + '.png')
        @suite.capture_screenshot(filename)
        @suite.p "-- SCREENSHOT CAPTURED TO: {#{filename}}"
        screenshot_flag = false
     rescue => e
        if screenshot_flag
           @suite.p "FAILED TO CAPTURE SCREENSHOT: "
           @suite.p e.inspect
           @suite.p e.backtrace
        end
      end
    end

    # -- figure out keyword of running test
    def get_keyword
       Dir.glob("#{@suite.suite_root}/tests/**/*_test.rb") {|f|
          file_contents = File.read(f)
          return /^#.*@keywords(.*$)/.match(file_contents)[0].gsub(/^#.*@keywords/, '').strip if /#{self.class.name}/.match(file_contents)
       }
    end

    # -- this method is overriden in subclass
    def run_main
    end

    # -- this method is overriden in subclass
    def setup
       @suite.p "\n:: [SETUP]\n"
       # -- let's print the description of each test first:
       Dir.glob("#{@suite.suite_root}/tests/**/*_test.rb") {|f|
          file_contents = File.read(f)
          @suite.p "\n   [description] : " + /^#.*@description(.*$)/.match(file_contents)[0].gsub(/^#.*@description/, '') + "\n\n" if /#{self.class.name}/.match(file_contents)
       }
    end

    # -- this method is overriden in subclass
    def teardown
       @suite.p "\n:: [TEARDOWN]\n"
    end
end
