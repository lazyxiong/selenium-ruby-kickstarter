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

require "net/http"

# -- check connection to Selenium RC
def check_connection
      one_wait = 5
      max_wait = 5
      request = Net::HTTP::Get.new('/')
      wait = 0;
      while (wait < max_wait)
          begin
              response = Net::HTTP.start(@url.host, @url.port) {|http|
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
          puts("-- ERROR: couldn't connect to test host on " + @url.host.to_s)
          return false
      end
      puts("-- SUCCESS: test host is alive !\n")
      return true
end

if ARGV.length < 1
   puts "-- usage: #{$0} test_host_url"
   exit(1)
end
@url = URI.parse(ARGV[0])
puts "-- host: " + @url.host.to_s
puts "-- port: " + @url.port.to_s

if (!check_connection)
   exit(1)
end
exit(0)
