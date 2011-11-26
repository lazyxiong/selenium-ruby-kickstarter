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
require 'base64'
require 'lib/ruby_suite'

class BaseTest
    attr_accessor :suite, :passed
    def initialize
       @suite  = RubySuite.new(:test_name => self.class.name)
       @passed = false
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
          save_screenshot
       ensure
          teardown
          @suite.clean_exit(@passed)
       end
    end

    def save_screenshot filename=nil
      @suite.p "CAPTURE SCREENSHOT"
      begin
        screenshot_flag = true
        filename = (ENV['REPORT_FILE'] + '.png') unless filename
        screenshot = @suite.selenium.capture_screenshot_to_string()
        tmp_file = File.open(filename,'w')
        tmp_file.puts(Base64.decode64(screenshot))
        tmp_file.close()
        @suite.p "SCREENSHOT CAPTURED TO #{filename}"
        screenshot_flag = false
        screenshot = @suite.selenium.capture_entire_page_screenshot_to_string()
        tmp_file = File.open(filename,'w')
        tmp_file.puts(Base64.decode64(screenshot))
        tmp_file.close()
        @suite.p "ENTIRE SCREENSHOT CAPTURED TO #{filename}"
     rescue => e
        if screenshot_flag
           @suite.p "FAILED TO CAPTURE SCREENSHOT: "
           @suite.p e.inspect
           @suite.p e.backtrace
        end
      end
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
          @suite.p "\n   [description] : " + /^#.*@description(.*$)/.match(file_contents)[0].gsub(/^#.*@description/, '') + "\n" if /#{self.class.name}/.match(file_contents)
       }
    end

    # -- this method is overriden in subclass
    def teardown
       @suite.p "\n:: [TEARDOWN]\n"
    end
end
