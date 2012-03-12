#!/usr/bin/env ruby
# Copyright (C) 2009 Alexandre Berman, (sashka@lazybear.net)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
require "lib/ruby_suite"

class BrowserSelenium

   def initialize(options)
      @suite       = options[:suite]
      @host        = options[:selenium_host]
      @port        = options[:selenium_port]
      @browser     = options[:browser]
      @full_screen = options[:full_screen]
      @base_url    = options[:base_url]
      do_init
   end

   # -- start selenium
   def do_init
      @selenium = Selenium::Client::Driver.new({:host => @host, :port => @port, :browser => @browser, :url => @base_url, :timeout_in_second => 10000})
      @selenium.start_new_browser_session
      @selenium.window_maximize if @full_screen
   end

   # -- navigate
   def navigate(url)
      @selenium.open(url)
   end

   # -- mouse_over
   def mouse_over(element)
      @suite.p("-- mousing over element: {#{element}}")
      @selenium.mouse_over(element)
   end

   # -- mouse_click
   def mouse_click(element)
      @suite.p("-- mouse-clicking element: {#{element}}")
      @selenium.mouse_down(element)
      @selenium.mouse_up(element)
   end

   # -- any_element_exist? (takes an array of elements)
   def any_element_exist?(elements_array)
      ok = false
      elements_array.each { |e|
         ok = true if element_exist?(e)
      }
      return ok
   end

   # -- element exist: true/false ?
   def element_exist?(element)
      out="-- does element exist ?: {" + element + "}"
      if !@selenium.is_element_present(element)
         @suite.p(out + " :: no\n")
         return false
      end
      @suite.p(out + " :: yes\n")
      return true
   end

   # -- clear specific cookie
   def clear_cookie(name, options)
      @suite.p("-- clearing cookie: #{name} with options [#{options}]...")
      @selenium.delete_cookie(name, options)
   end

   # -- check something
   def check(element)
      @suite.p("-- checking element ['#{element}']")
      @selenium.check(element)
   end

   # -- uncheck something
   def uncheck(element)
      @suite.p("-- unchecking element ['#{element}']")
      @selenium.uncheck(element)
   end

   # -- click on something
   def click(element)
      # -- 'element' could be a javascript, then we need to call 'run_script' instead of 'click'
      if /jQuery/.match(element)
         @suite.p("-- running script: " + element)
         @selenium.run_script(element)
      else
         @suite.p("-- clicking on element: " + element)
         @selenium.click(element)
      end
   end

   # -- partial link text click
   def partial_link_text_click(element)
      @suite.p("-- clicking on partial link: " + element)
      @suite.p("   :: NOT IMPLEMENTED FOR SELENIUM - PLEASE, SWITCH TO WEBDRIVER ! ::")
      @suite.p("   :: GOING TO TRY REGULAR CLICK, BUT SUCCESS IS NOT GUARANTEED... ::")
      click(element)
   end

   # -- clear
   def clear(element)
      @suite.p("-- clearing element ['#{element}']")
      @selenium.type(element, "")
   end

   # -- type something into something
   def type(element, text)
      @suite.p("-- typing text ['#{text}'] into element ['#{element}']")
      @selenium.type(element, text)
   end

   # -- select something
   def select(element, option)
      @suite.p("-- selecting option ['#{option}'] from select element ['#{element}']")
      @selenium.select(element, option)
   end

   # -- get_eval
   def get_eval(eval_expression)
      @suite.p("-- evaluating expression: " + eval_expression)
      e = @selenium.get_eval(eval_expression)
      @suite.p("-- expression evaluated to: " + e)
      return e
   end

   # -- is checked ?
   def is_checked?(element)
      return true if (@selenium.is_checked(element))
      return false
   end

   # -- is selected ?
   def is_selected?(select_element, option)
      return true if (option == @selenium.get_selected_value(select_element))
      return false
   end

   # -- check if location (url) contains given pattern
   def location_has?(pattern)
      if !/#{pattern}/.match(@selenium.get_location)
         return false
      end
      return true
   end

   # -- verify location pattern
   def verify_location(pattern)
      @suite.p("-- checking if location (absolute url of this page) has pattern: {#{pattern}}")
      @suite.p("-- current page location (url) is: #{@selenium.get_location}")
      if location_has?(pattern)
         @suite.p("-- pattern matched")
      else
         raise "-- ERROR: pattern not found in current page location !"
      end
   end

   # -- extract page element and compare its value to a given one
   def extract_text_and_compare(location_id, compare_value)
      @suite.p("-- checking location_id [ " + location_id + " ] for the following value: " + compare_value)
      @suite.p("-- current value in a given location_id: " + @selenium.get_text(location_id))
      if (@selenium.get_text(location_id) != compare_value)
         raise "-- ERROR: " + compare_value + "not found in [ " + location_id + " ]"
      else
         @suite.p("-- OK: [ " + compare_value + " ] found!")
      end
   end

   # -- get_body_text
   def get_body_text
      begin
         return @selenium.get_body_text()
      rescue Selenium::CommandError => e
         # -- if this happened, most likely page is not yet fully loaded, then we wait and try one more time
	 @suite.p("-- exception caught: {Selenium::CommandError}. Page is probably not fully loaded, will wait for 5 sec and try again...")
	 sleep 5
         return @selenium.get_body_text()
      end
   end

   # -- get_html_source
   def get_html_source
      return @selenium.get_html_source()
   end

   # -- capture_screenshot
   def capture_screenshot(file)
      screenshot = @selenium.capture_screenshot_to_string()
      tmp_file = File.open(file,'w')
      tmp_file.puts(Base64.decode64(screenshot))
      tmp_file.close()
   end

   # -- quit
   def quit
      @selenium.close_current_browser_session if defined?(@selenium)
   end

end
