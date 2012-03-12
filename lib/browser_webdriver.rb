#!/usr/bin/env ruby
# Copyright (C) 2012 Alexandre Berman, (sashka@lazybear.net)
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
require 'lib/ruby_suite'

class BrowserWebdriver

   def initialize(options)
      @suite   = options[:suite]
      @host    = options[:selenium_host]
      @port    = options[:selenium_port]
      @browser = options[:browser]
      do_init
   end

   # -- start selenium
   def do_init
      caps_chrome = Selenium::WebDriver::Remote::Capabilities.chrome
      caps_chrome[:name] = "Win 7 Chrome Browser"
      caps_chrome[:acceptSslCerts] = true
      caps_ie = Selenium::WebDriver::Remote::Capabilities.ie
      caps_ie[:name] = "Win 7 IE8 Browser"
      caps_ie[:acceptSslCerts] = true
      caps_ie[:ENSURING_CLEAN_SESSION] = true
      @caps = case @browser
         when /google/ then caps_chrome
         when /ie/ then caps_ie
	 else caps_chrome
      end
      @driver = Selenium::WebDriver.for( :remote, :url => "http://#{@host}:#{@port}/wd/hub", :desired_capabilities => @caps)
   end

   def obtain_element(element)
      begin
         case element
            when /id=/ then return @driver.find_element(:id, element.gsub(/id=/, ''))
            when /link=/ then return @driver.find_element(:link, element.gsub(/link=/, ''))
      	    when /\/\// then return @driver.find_element(:xpath, element)
      	    else return nil
         end
      rescue => e
         raise "-- ERROR: got an exception while trying to obtain element => {#{element}} !"
      end
   end

   # -- get element
   def get_element(element)
      begin
         return obtain_element(element)
      rescue => e
	 return nil
      end
   end

   # -- mouse over
   def mouse_over(element)
      @suite.p("-- mousing over element: {#{element}}")
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      @driver.mouse.move_to this_element
   end

   def mouse_click(element)
      @suite.p("-- mouse-clicking element: {#{element}}")
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      @driver.mouse.move_to this_element
      @driver.mouse.click this_element
   end

   # -- element exist: true/false ?
   def element_exist?(element)
      this_element = get_element(element)
      out="-- does element exist ?: {" + element + "}"
      if !this_element
         @suite.p(out + " :: no\n")
         return false
      end
      @suite.p(out + " :: yes\n")
      return true
   end

   # -- clear specific cookie
   def clear_cookie(name, options)
      @suite.p("-- clearing cookie: #{name} with options [#{options}]...")
      @driver.manage.all_cookies.each { |c| @suite.p("-- cookies: name => " + c[:name] + " || value => " + c[:value]) }
      @driver.manage.delete_cookie(name)
      @driver.manage.delete_all_cookies
   end

   #TODO
   # -- get_eval
   def get_eval(eval_expression)
      @suite.p("-- evaluating expression: " + eval_expression)
      #e = @selenium.get_eval(eval_expression)
      @suite.p("-- expression evaluated to: " + e)
      return e
   end

   # -- navigate
   def navigate(url)
      begin
         @driver.navigate.to(url)
      rescue => e
         @suite.do_fail("-- ERROR: navigating to page failed !\n" + e.inspect)  
      end
   end

   # -- check: alias for .click
   def check(element)
      click(element)
   end

   # -- uncheck: alias for .click
   def uncheck(element)
      click(element)
   end

   # -- click on something
   def click(element)
      @suite.p("-- clicking on element: " + element)
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      this_element.click
   end

   # -- partial link text click
   def partial_link_text_click(element)
      @suite.p("-- clicking on partial link: " + element)
      this_element = @driver.find_element(:partial_link_text, element.gsub(/link=/, ''))
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      this_element.click
   end

   # -- clear element
   def clear(element)
      @suite.p("-- clearing element ['#{element}']")
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      this_element.clear
   end

   # -- type something into something
   def type(element, text)
      @suite.p("-- typing text ['#{text}'] into element ['#{element}']")
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      this_element.send_keys(text)
   end

   # -- select something
   def select(element, option)
      @suite.p("-- selecting option ['#{option}'] from select element ['#{element}']")
      dropdown = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless dropdown
      selected = dropdown.find_elements(:tag_name, "option").detect { |opt| opt.attribute('text').eql?(option) }
      raise "-- ERROR: can't find option {#{option}} in dropdown list" if selected.nil?
      selected.click
   end

   # -- is selected ?
   def is_selected?(element, option)
      @suite.p("-- is option ['#{option}'] selected in the element ['#{element}']")
      dropdown = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless dropdown
      selected = dropdown.find_elements(:tag_name, "option").detect { |opt| opt.attribute('text').eql?(option) }
      return false if selected.nil?
      return true
   end

   # -- is checked ?
   def is_checked?(element)
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      return true if this_element.selected?
      return false
   end

   # -- check if location (url) contains given pattern
   def location_has?(pattern)
      if !/#{pattern}/.match(@driver.current_url)
         return false
      end
      return true
   end

   # -- verify location pattern
   def verify_location(pattern)
      @suite.p("-- checking if location (absolute url of this page) has pattern: {#{pattern}}")
      @suite.p("-- current page location (url) is: #{@driver.current_url}")
      if location_has?(pattern)
         @suite.p("-- pattern matched")
      else
         raise "-- ERROR: pattern not found in current page location !"
      end
   end

   # -- extract page element and compare its value to a given one
   def extract_text_and_compare(element, compare_value)
      @suite.p("-- checking element [ " + location_id + " ] for the following value: " + compare_value)
      this_element = get_element(element)
      raise "-- ERROR: for some reason {#{element}} element was not found !" unless this_element
      @suite.p("-- current value in a given element: " + this_element.text)
      if (this_element.text != compare_value)
         raise "-- ERROR: " + compare_value + "not found in [ " + element + " ]"
      else
         @suite.p("-- OK: [ " + compare_value + " ] found!")
      end
   end

   # -- get_body_text
   def get_body_text
      return @driver.find_element(:tag_name => "body").text
   end

   # -- get_html_source
   def get_html_source
      return @driver.page_source
   end

   # -- capture_screenshot
   def capture_screenshot(file)
      @driver.save_screenshot(file)
   end

   # -- quit
   def quit
      @driver.quit if defined?(@driver)
   end
end
