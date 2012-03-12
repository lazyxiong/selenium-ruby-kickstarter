#!/usr/bin/env ruby
# Copyright (C) 2009 Alexandre Berman, Lazybear Consulting (sashka@lazybear.net)
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

require 'yaml'
require "rubygems"
require "lib/browser_webdriver"
require "lib/browser_selenium"
require "lib/macros"
require "lib/base_test"
require "lib/user"
require 'tlsmail'
require 'fileutils'
require 'base64'
require 'nokogiri'
require 'open-uri'
require 'httpi-ntlm'
require 'date'
require 'net/http'

class RubySuite
   attr_accessor :driver, :test_name, :CONFIG, :base_url, :debug_mode, :dump_body_on_error, :suite_root, :common, :max_sleep_time

   def initialize(options)
      @suite_root = File.expand_path "#{File.dirname(__FILE__)}/.."
      # -- loading global properties from yaml
      @CONFIG = read_yaml_file(@suite_root+"/env.yaml")
      # -- loading user-defined properties from yaml
      if File.exist?(@suite_root+"/user.env.yaml")
         YAML::load(File.read(@suite_root+"/user.env.yaml")).each_pair { |key, value|
            @CONFIG[key] = value if @CONFIG[key] != nil
         }
      end
      # -- loading common id hash
      @common = YAML::load(File.read(@suite_root+"/lib/common.yaml"))
      @debug_mode = @CONFIG['debug_mode']
      @max_sleep_time = @CONFIG['max_sleep_time']
      # -- below is an attempt to reeavaluate proper base_url based on either CONFIG['base_url'] or ENV['qa_base_url']
      @base_url = proper_base_url
      @dump_body_on_error = @CONFIG['dump_body_on_error']
      # -- setting env for a given test
      set_test_name(options[:test_name])
      # -- check connection to Selenium Server and initiate the driver
      check_connection
      do_init
   end

   # -- utility method for reading yaml data
   def read_yaml_file(file)
      if File.exist?(file)
         return YAML::load(File.read(file))
      end
      raise "-- ERROR: file doesn't exist: " + file
   end

   # -- check connection to Selenium Server
   def check_connection
      one_wait = 5
      max_wait = 15
      request = Net::HTTP::Get.new('/selenium-server/')
      wait = 0;
      while (wait < max_wait)
          begin
              response = Net::HTTP.start(@CONFIG['selenium_host'], @CONFIG['selenium_port']) {|http|
                  http.request(request)
              }
              break if Net::HTTPForbidden === response
              break if Net::HTTPNotFound === response
              break if Net::HTTPSuccess === response
              # When we try to connect to a down server with an Apache proxy,
              # we'll get Net::HTTPBadGateway and get here
          rescue Errno::ECONNREFUSED
              # When we try to connect to a down server without an Apache proxy,
              # such as a dev instance, we'll get here
          end
          sleep one_wait;
          wait += one_wait
      end
      raise "-- ERROR: couldn't connect to Selenium Server on " + @CONFIG['selenium_host'] if (wait == max_wait)
      p("-- SUCCESS      : Selenium Server is alive !")
   end

   # -- start selenium
   def do_init
      begin
         p("-- ENV          : " + RUBY_PLATFORM)
	 p("-- Selenium Host: " + @CONFIG['selenium_host'])
	 p("-- Selenium Port: " + @CONFIG['selenium_port'])
         p("-- BROWSER      : " + @CONFIG['browser'])
	 p("-- base_url     : " + @base_url)
	 case @CONFIG['driver']
	    when /webdriver/
               require "selenium-webdriver"
	       @driver = BrowserWebdriver.new({
	          :suite         => self,
	          :selenium_host => @CONFIG['selenium_host'], 
		  :selenium_port => @CONFIG['selenium_port'], 
		  :browser       => @CONFIG['browser']})
	    when /selenium/
               require "selenium/client"
	       @driver = BrowserSelenium.new({
	          :suite         => self,
	          :selenium_host => @CONFIG['selenium_host'], 
		  :selenium_port => @CONFIG['selenium_port'], 
		  :browser       => @CONFIG['browser'],
		  :base_url      => @base_url,
		  :full_screen   => @CONFIG['fullscreen_mode']})
	    else 
	       raise "-- ERROR: no correct driver was defined in env.yaml - either 'selenium' or 'webdriver' should be defined !"
	 end
	 p("-- Driver       : " + @driver.class.name)
      rescue => e
         do_fail("-- ERROR: " + e.inspect)
         clean_exit(false)
      end
   end

   # -- check the page for any abnormalities
   def check_page(page)
      # -- if error is found, it will dump first 2000 characters of the page to the screen
      raise "-- [ERROR] User name incorrect !\n\n" if /User name or password is incorrect/.match(page)
      raise "-- [ERROR] Oops word found !\n\n" if /Oops/.match(page)
      raise "-- [ERROR] 404 Document not found !\n\n" if /was not found on this server/.match(page)
      raise "-- [ERROR] phrase 'is null or undefined, not a Function object' found !\n\n" if/is null or undefined, not a Function object/.match(page)
      raise "-- [ERROR] phrase 'is null or undefined' found !\n\n" if /is null or undefined/.match(page)
      raise "-- [ERROR] phrase 'Internal Server Error' found !\n\n" if /Internal Server Error/.match(page)
      raise "-- [ERROR] phrase 'Service Unavailable' found !\n\n" if /Service Unavailable/.match(page)
      raise "-- [ERROR] phrase 'Service Temporarily Unavailable' found !\n\n" if /Service Temporarily Unavailable/.match(page)
      raise "-- [ERROR] phrase 'Rate limit exceeded' found !\n\n" if /Rate limit exceeded/.match(page)
      if /An Error Occurred/.match(page)
         p ("-- Error occured, dumping partial stack trace to the screen...")
         page[0,2000].each { |s| p s } if page.length >= 2000
         raise "-- [ERROR] Exception occured !\n\n"
      end
   end

   # -- mouse_over
   def mouse_over(element)
      @driver.mouse_over(element)
   end

   # -- mouse_click
   def mouse_click(element)
      @driver.mouse_click(element)
   end

   # -- element exist: true/false ?
   def element_exist?(element)
      check_page(get_body_text())
      @driver.element_exist?(element)
   end

   # -- verify particular element
   def verify_element(element)
      p("-- Verifying page elements...")
      raise "-- [ERROR] not able to verify element: #{element}" if !element_exist?(element)
      p("-- OK: page element verified [ #{element} ] !")
   end

   # -- any_element_exist? (takes an array of elements)
   def any_element_exist?(elements_array)
      ok = false
      elements_array.each { |e|
         ok = true if element_exist?(e)
      }
      return ok
   end

   # -- wait_for_any_element
   def wait_for_any_element(elements_array)
      max_sleep = @max_sleep_time
      sleep_now = 1 
      while (!any_element_exist?(elements_array))
         sleep_now += 1
         raise "-- ERROR: waited too long (#{sleep_now.to_s} seconds) for any of the elements (#{elements_array}) to appear !" if sleep_now > max_sleep
         sleep 1
      end
   end

   # -- wait_for_element
   def wait_for_element(element)
      max_sleep = @max_sleep_time
      sleep_now = 1 
      while (!element_exist?(element))
         sleep_now += 1
      	 raise "-- ERROR: waited too long (#{sleep_now.to_s} seconds) for element (#{element}) to appear !" if sleep_now > max_sleep
      	 sleep 1
      end
   end

   # -- wait_for_element_to_disappear
   def wait_for_element_to_disappear(element)
      max_sleep = @max_sleep_time
      sleep_now = 1 
      while (element_exist?(element))
         sleep_now += 1
	 raise "-- ERROR: waited too long (#{sleep_now.to_s} seconds) for element (#{element}) to disappear !" if sleep_now > max_sleep
	 sleep 1
      end
   end

   # -- text exist: true/false ?
   def text_exist?(text)
      body = get_body_text
      check_page(body)
      out="-- does text exist ?: {" + text + "}"
      if !body.include?(text)
         p(out + " :: no\n")
         return false
      end
      p(out + " :: yes\n")
      return true
   end

   # -- verify text
   def verify_text(text)
      p("-- Verifying page text: [ #{text} ]")
      if !text_exist?(text)
         raise "-- [ERROR] not able to verify text: #{text}"
      end
      p("-- OK: page text verified [ #{text} ] !")
   end

   # -- wait_for_text
   def wait_for_text(text)
      max_sleep = @max_sleep_time
      sleep_now = 1 
      while (!text_exist?(text))
         sleep_now += 1
      	 raise "-- ERROR: waited too long (#{sleep_now.to_s} seconds) for text (#{text}) to appear !" if sleep_now > max_sleep
      	 sleep 1
      end
   end

   # -- wait_for_text_to_disappear
   def wait_for_text_to_disappear(text)
      max_sleep = @max_sleep_time
      sleep_now = 1 
      while (text_exist?(text))
         check_page(get_body_text())
         sleep_now += 1
	 raise "-- ERROR: waited too long (#{sleep_now.to_s} seconds) for text (#{text}) to disappear !" if sleep_now > max_sleep
	 sleep 1
      end
   end


   # -- verify text using pattern matching rather than is_text_present method
   def blury_verify_text(text)
      page = get_body_text
      check_page(page)
      p("-- searching for text using pattern matching, text: {#{text}}")
      if !/#{text}/.match(page)
         raise "-- [ERROR]: not able to find text: {#{text}} anywhere in the page"
      end
      p("-- OK: text {#{text}} verified")
   end

   # -- get the right cookie out of common.yaml: provide cookie name and it will get the right one based on site_type
   def get_cookie(cookie_name)
      return @common['site_type'][self.site_type]['cookies'][cookie_name]
   end

   # -- clear specific cookie
   def clear_cookie(name, options)
      @driver.clear_cookie(name, options)
   end

   # -- get_eval
   def get_eval(eval_expression)
      return @driver.get_eval(eval_expression)
   end

   # -- navigate
   def navigate(url)
      @driver.navigate(url)
   end

   # -- click on something
   def click(element)
      @driver.click(element)
   end

   # -- click on a partial link text: only implemented for Webdriver
   def partial_link_text_click(element)
      @driver.partial_link_text_click(element)
   end

   # -- type something into something
   def type(element, text)
      @driver.clear(element)
      @driver.type(element, text)
   end

   # -- select something
   def select(element, option)
      @driver.select(element, option)
   end

   # -- is checked ?
   def is_checked?(element)
      @driver.is_checked?(element)
   end

   # -- verify checked
   def verify_checked(element)
      p("-- verifying if {#{element}} is checked...")
      if (is_checked?(element))
         p("-- OK")
      else
         raise "-- ERROR: option {#{element}} is not checked on the page !"
      end
   end

   # -- verify selected
   def verify_selected(select_element, option)
      p("-- verifying if {#{option}} is selected...")
      if (is_selected?(select_element, option))
         p("-- OK")
      else
         raise "-- ERROR: option {#{option}} is not selected on the page !"
      end
   end

   # -- is selected ?
   def is_selected?(select_element, option)
      @driver.is_selected?(select_element, option)
   end

   # -- check something: alias for .click
   def check(element)
      #click(element)
      @driver.check(element)
   end

   # -- uncheck something: alias for .click
   def uncheck(element)
      #click(element)
      @driver.uncheck(element)
   end

   # -- check if location (url) contains given pattern
   def location_has?(pattern)
      @driver.location_has?(pattern)
   end

   # -- verify location pattern
   def verify_location(pattern)
      @driver.verify_location(pattern)
   end

   # -- extract page element and compare its value to a given one
   def extract_text_and_compare(element, compare_value)
      @driver.extract_text_and_compare(element, compare_value)
   end

   # -- get_body_text
   def get_body_text
      begin
         @driver.get_body_text
      rescue => e
         # -- if we got an exception here, most likely cause is page not fully loaded, so we wait a bit and try one more time
	 sleep 3
	 return @driver.get_body_text
      end
   end

   # -- get_html_source
   def get_html_source
      @driver.get_html_source
   end

   # -- capture_screenshot
   def capture_screenshot(file)
      @driver.capture_screenshot(file)
   end

   # -- set test_name
   def set_test_name(new_name)
      @test_name = new_name
      p "\n\n:: {BEGIN} [#{@test_name}] ++++++++++++++++++\n\n"
   end

   # -- do_fail
   def do_fail(s)
      p(s)
      raise("error")
   end

   # -- generate random number
   def random_n
      return rand(50000).to_s.rjust(5,'0')
   end

   # -- custom print method
   def p(s)
      puts s
   end

   # -- generic function to match pattern against given text
   def match_pattern_in_text(pattern, text)
      p("-- searching for text using pattern matching")
      output = "   => pattern: {#{pattern}}"
      if !/#{pattern.downcase}/.match(text.downcase)
         output += "   => [WARNING]: not able to verify pattern, text follows:\n\n" + text
	 return false
      end
      output += "   => [OK]: pattern verified"
      p(output)
      return true
   end

   # -- figure out proper base_url
   def proper_base_url
      p("-- evaluating the proper base url to use based on config settings...")
      if (ENV['qa_base_url'] != nil and ENV['qa_base_url'] != "")
         p("-- using ENV - URL: " + ENV['qa_base_url'])
         return ENV['qa_base_url']
      else
         p("-- using env.yaml file URL: " + @CONFIG['base_url'])
         return @CONFIG['base_url']
      end
   end

   # -- construct new url
   def create_url(relative_url)
      return @base_url + relative_url
   end

   # -- setup proper file uri needed for any operations involving selenium.attach_file
   def proper_file_uri(file)
      p("-- setting up proper file uri for file: [ #{file} ]")
      case RUBY_PLATFORM
        when /cygwin/, /mswin32/, /i386-mingw32/
           new_path = file.gsub(/C:/,'')
           p("-- new_path (windows only) = #{new_path}")
           return "file://" + new_path
        else
           return "file://" + file
      end
   end

   # -- operations on DIR(s): rm_dir
   def rm_dir(dir)
      if File.directory?(dir)
         p("-- removing dir: " + dir)
         FileUtils.rm_r(dir)
      end
   end

   # -- operations on DIR(s): mkdir
   def mkdir(dir)
      if !File.directory?(dir)
         p("-- creating dir: " + dir)
         FileUtils.mkdir_p(dir)
      end
   end

   # -- operations on DIR(s): setup_dir
   def setup_dir(dir)
      rm_dir(dir)
      mkdir(dir)
   end

   # -- convert string to boolean
   def string_to_boolean(option)
      return true if option == true || option =~ (/(true|t|yes|y|1)$/i)
      return false if option == false || option.nil? || option =~ (/(false|f|no|n|0)$/i)
   end

   # -- check pop mail
   def pop_mail(login, password)
      all_mails = []
      ok = true
      begin
         Net::POP.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
         Net::POP.start(@CONFIG['pop_host'], @CONFIG['pop_port'], login, password) do |pop|
            if pop.mails.empty?
               p '-- (pop) No mail.'
            else
               i = 0
               pop.each_mail do |m|
                  #exit if i > 20
                  p "-- (pop) >>> new message ..."
                  all_mails.push(m.pop)
                  m.delete #can be deleted if each_mail will be replaced with delete_all
                  p "-- (pop) >>> end ..."
                  i=i+1
               end
            end
         end
      rescue Net::POPAuthenticationError => err
         p err
         ok = !ok
         unless ok
            retry
         else
            raise
         end
      end
      return all_mails
   end

   # -- clean exit
   def clean_exit(status)
      p "-- exiting test framework..."
      begin
	 if (status)
            @driver.quit if defined?(@driver)
	 else
            p(get_body_text) if @dump_body_on_error
	    if !@debug_mode
               @driver.quit if defined?(@driver)
	    end
	 end
      rescue => e
         p("ERROR: ")
         p e.inspect
         p e.backtrace
         status = false
      ensure
         if (status)
            p "-- PASSED !"
            exit @CONFIG['STATUS_PASSED']
         else
            p "-- FAILED !"
            exit @CONFIG['STATUS_FAILED']
         end
      end
   end
end
