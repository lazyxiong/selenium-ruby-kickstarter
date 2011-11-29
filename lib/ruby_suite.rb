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
require "selenium/client"
require "lib/macros"
require "lib/base_test"
require "lib/user"
require 'tlsmail'
require 'fileutils'

class RubySuite
   attr_accessor :selenium, :test_name, :CONFIG, :host, :port, :base_url, :browser, :debug_mode, :suite_root, :common

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
      @host = @CONFIG['selenium_host']
      @port = @CONFIG['selenium_port']
      @browser = @CONFIG['browser']
      @debug_mode = @CONFIG['debug_mode']
      @base_url = @CONFIG['base_url']
      # -- setting env for a given test
      set_test_name(options[:test_name])
      # -- do init
      do_init
   end

   # -- utility method for reading yaml data
   def read_yaml_file(file)
      if File.exist?(file)
         return YAML::load(File.read(file))
      end
      raise "-- ERROR: file doesn't exist: " + file
   end

   # -- check connection to Selenium RC
   def check_connection
      one_wait = 5
      max_wait = 15
      request = Net::HTTP::Get.new('/selenium-server/')
      wait = 0;
      while (wait < max_wait)
          begin
              response = Net::HTTP.start(@host, @port) {|http|
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
      if (wait == max_wait)
          p("-- ERROR: couldn't connect to Selenium RC on " + @host)
          return false
      end
      return true
   end

   # -- start selenium
   def do_init
      if (!check_connection)
         clean_exit(false)
      end
      begin
         p("-- SUCCESS : Selenium RC is alive !\n")
         p("-- ENV          : " + RUBY_PLATFORM)
	 p("-- Selenium Host: " + @host)
         p("-- BROWSER      : " + @browser)
         @selenium = Selenium::Client::Driver.new \
           :host => @host,
           :port => @port,
           :browser => @browser,
           :url => @base_url,
           :timeout_in_second => 10000
         @selenium.start_new_browser_session
         @selenium.window_maximize if @CONFIG["fullscreen_mode"]
      rescue => e
         do_fail("ERROR: " + e.inspect)
         clean_exit(false)
      end
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

   # -- check the page for any abnormalities
   def check_page(page)
      # -- if error is found, it will dump first 2000 characters of the page to the screen
      raise "-- [ERROR] User name incorrect !\n\n" if /User name or password is incorrect/.match(page)
      if /An Error Occurred/.match(page)
         p ("-- Error occured, dumping partial stack trace to the screen...")
         page[0,2000].each { |s| p s } if page.length >= 2000
         raise "-- [ERROR] Exception occured !\n\n"
      end
   end

   # -- element exist: true/false ?
   def element_exist?(element)
      if !@selenium.is_element_present(element)
         return false
      end
      return true
   end

   # -- verify particular element
   def verify_element(element)
      p("-- Verifying page elements...")
      raise "-- [ERROR] not able to verify element: #{element}" if !element_exist?(element)
      p("-- OK: page element verified [ #{element} ] !")
   end

   # -- verify text
   def verify_text(text)
      p("-- Verifying page text: [ #{text} ]")
      sleep_in_slow_mode 8
      if !@selenium.is_text_present(text)
         p("-- text not found, page text is currently: " + @selenium.get_body_text() )
         raise "-- [ERROR] not able to verify text: #{text}"
      end
      p("-- OK: page text verified [ #{text} ] !")
   end

   # -- clear all necessary cookies
   def clear_cookies_disabled
      p("-- clearing browser_token cookie...")
      @selenium.delete_cookie("browser_token", "recurse=true")
   end

   # -- clear cookies in a creative way
   def clear_cookies
      p("-- clearing browser_token cookie...")
      js =  "var cookie_date = new Date ( ); cookie_date.setTime ( cookie_date.getTime() - 1 );"
      js += " document.cookie = 'browser_token =; expires=' + cookie_date.toGMTString();"
      p("-- javascript: " + js + "\n\n")
      @selenium.run_script(js)
   end

   def sleep_in_slow_mode time=1
     sleep time if @CONFIG["slow_mode"]
   end

   # -- wait for page to load and verify text
   def wait_for_page_and_verify_text(text)
      @selenium.wait_for_page_to_load(120000)
      check_page_and_verify_text(text)
   end

   # -- check the page for any abnormalities and verify text
   def check_page_and_verify_text(text)
      check_page(@selenium.get_body_text())
      verify_text(text)
   end

   # -- click on something
   def click(element)
      # -- 'element' could be a javascript, then we need to call 'run_script' instead of 'click'
      if /jQuery/.match(element)
         p("-- running script: " + element)
         @selenium.run_script(element)
      else
         p("-- clicking on element: " + element)
         @selenium.click(element)
      end
   end

   # -- type something into something
   def type(element, text)
      p("-- typing text ['#{text}'] into element ['#{element}']")
      @selenium.type(element, text)
   end

   # -- select something
   def select(element, option)
      p("-- selecting option ['#{option}'] from select element ['#{element}']")
      @selenium.select(element, option)
   end

   # -- get_eval
      def get_eval(eval_expression)
      p("-- evaluating expression: " + eval_expression)
      e = @selenium.get_eval(eval_expression)
      p("-- expression evaluated to: " + e)
      return e
   end

   # -- check something
   def check(element)
      p("-- checking element ['#{element}']")
      @selenium.check(element)
   end

   # -- uncheck something
   def uncheck(element)
      p("-- unchecking element ['#{element}']")
      @selenium.uncheck(element)
   end

   def p(s)
      puts s
   end

   # -- setup proper absolute url based on a given relative url
   def proper_base_url(relative_url)
      p("-- evaluating the proper base url to use based on config settings: " + relative_url)
      if (ENV['qa.base.url'] != nil and ENV['qa.base.url'] != "")
         p("-- using ENV - URL: " + ENV['qa.base.url'])
         proper_base = (ENV['qa.base.url'] + relative_url)
      else
         p("-- using env.yaml file URL: " + @base_url)
         proper_base = (@base_url + relative_url)
      end
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

   # -- extract page element and compare its value to a given one
   def extract_text_and_compare(location_id, compare_value)
      p("-- checking location_id [ " + location_id + " ] for the following value: " + compare_value)
      p("-- current value in a given location_id: " + @selenium.get_text(location_id))
      if (@selenium.get_text(location_id) != compare_value)
         raise "-- ERROR: " + compare_value + "not found in [ " + location_id + " ]"
      else
         p("-- OK: [ " + compare_value + " ] found!")
      end
   end

   # -- extract text field element and compare its value to a given one
   def extract_value_and_compare(location_id, compare_value)
      p("-- checking location_id [ " + location_id + " ] for the following value: " + compare_value)
      p("-- current value in a given location_id: " + @selenium.get_text(location_id))
      if (@selenium.get_value(location_id) != compare_value)
         raise "-- ERROR: " + compare_value + "not found in [ " + location_id + " ]"
      else
         p("-- OK: [ " + compare_value + " ] found!")
      end
   end

   def wait_for_element_present locator, timeout = 120
      @selenium.wait_for_condition("selenium.isElementPresent(\"#{locator}\")", timeout)
   end

   def wait_for_element_not_present locator, timeout = 120
      @selenium.wait_for_condition("!selenium.isElementPresent(\"#{locator}\")", timeout)
   end

   def wait_for_element_visible locator, timeout = 120
      p "-- waiting for visible #{locator}"
      wait_for_element_present locator, timeout
      @selenium.wait_for_condition("selenium.isVisible(\"#{locator}\")", timeout)
   end

   def wait_for_element_not_visible locator, timeout = 120
      wait_for_element_present locator, timeout
      @selenium.wait_for_condition("!selenium.isVisible(\"#{locator}\")", timeout)
   end

   def wait_for_text_present locator, timeout = 120
      @selenium.wait_for_condition("selenium.isTextPresent(\"#{locator}\")", timeout)
   end

   def get_body_text
      return @selenium.get_body_text()
   end

   # -- operations on DIR(s)
   def rm_dir(dir)
      if File.directory?(dir)
         p("-- removing dir: " + dir)
         FileUtils.rm_r(dir)
      end
   end

   def mkdir(dir)
      if !File.directory?(dir)
         p("-- creating dir: " + dir)
         FileUtils.mkdir_p(dir)
      end
   end

   def setup_dir(dir)
      rm_dir(dir)
      mkdir(dir)
   end

   # -- connect to db
   def mysql_open
      begin
         #@dbh = Mysql.real_connect("10.7.144.128", "charlie", "m1ll3r", "adz")
         @dbh = Mysql.real_connect(@CONFIG['mysql_host'], @CONFIG['mysql_user'], @CONFIG['mysql_password'], @CONFIG['mysql_db'])
         # -- debug: get server version string and display it
         #puts "Server version: " + @dbh.get_server_info
      rescue Mysql::Error => e
         p("-- MySql Error code: #{e.errno}")
         p("-- MySql Error message: #{e.error}")
         p("-- MySql Error SQLSTATE: #{e.sqlstate}") if e.respond_to?("sqlstate")
         mysql_close
         clean_exit(false)
      end
   end

   # -- db close
   def mysql_close
      begin
         # -- disconnect from server
         @dbh.close if @dbh
      rescue Mysql::Error => e
         p("-- MySql Error code: #{e.errno}")
         p("-- MySql Error message: #{e.error}")
         p("-- MySql Error SQLSTATE: #{e.sqlstate}") if e.respond_to?("sqlstate")
         clean_exit(false)
      end
   end

   # -- mysql queries
   def mysql_q(q)
      if @dbh
         begin
            #[12698887, 10588603, 12698885, 12695201, 12061713].each  { |b|
            #   puts("-- checking id: " + b.to_s)
            #res = @dbh.query("select status_from_user from banner where banner_id = #{b.to_s}")
            res = @dbh.query(q)
            res.each { |row| yield row }
            #   printf "%s, %s\n", row[0], row[1]
               #puts "Number of rows returned: #{res.num_rows}\n\n"
               #res.free
            #}
         rescue Mysql::Error => e
            p("-- Error code: #{e.errno}")
            p("-- Error message: #{e.error}")
            p("-- Error SQLSTATE: #{e.sqlstate}") if e.respond_to?("sqlstate")
            mysql_close
            clean_exit(false)
         end
      else
      end
   end

   # -- check pop mail
   def pop_mail(login, password)
      all_mails = []
      ok = true
      begin
         Net::POP.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
         Net::POP.start(@common['pop_host'], @common['pop_port'], login, password) do |pop|
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
         if (@debug_mode)
            if (status)
               @selenium.close_current_browser_session if defined?(@selenium)
            end
         else
            @selenium.close_current_browser_session if defined?(@selenium)
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
