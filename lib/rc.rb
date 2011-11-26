#!/usr/bin/env ruby
#    Copyright (C) 2010 Alexandre Berman, Lazybear Consulting (sashka@lazybear.net)
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
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#    Script to start/stop Selenium RC
#
require 'net/http'
require 'shell'
require 'yaml'

if (ARGV.empty? || ARGV.length > 1)
       puts "-- usage: " + $0 + " start|stop"
       exit 1
end

class RC

      def initialize(options)
        @option     = options
        @suite_root = File.expand_path "#{File.dirname(__FILE__)}/.."
        # -- loading global properties from yaml
        @CONFIG     = YAML::load(File.read(@suite_root+"/env.yaml"))
	@host       = @CONFIG['selenium_host']
	@port       = @CONFIG['selenium_port']
	@jar_file   = @suite_root + "/" + @CONFIG['selenium_jar']
        @timeout_in_seconds = "60"
        @shutdown_command = "shutDownSeleniumServer"
        @shell = Shell.new
        @log_file = "selenium-server.log"
      end

      def process
        if @option == "start"
	  start
	elsif @option == "stop"
	  stop
	else
	  puts "Error: unknown option - " + @option
        end
      end

      def start
        command = "java -jar \"#{@jar_file}\""
        command << " -port #{@port}"
        command << " -multiWindow"
        #command << " -singlewindow"
        command << " -timeout #{@timeout_in_seconds}"
        command << " > #{@log_file}"
        Thread.new { `#{command}` }
      end

      def stop
        Net::HTTP.get(@host, "/selenium-server/driver/?cmd=#{@shutdown_command}", @port)
      end

end
RC.new(ARGV[0]).process
