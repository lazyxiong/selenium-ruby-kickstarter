#!/usr/bin/env ruby
require 'lib/ruby_suite'

# -- This class will hold basic user information and some methods for user's actions.
#    Some examples of how it can be used:
#    @user1    = User.new(@suite) # -- default values
#    @user2    = User.new(@suite, {:full_name => "Superman", :email => "qab@gmail.com", :login_name => "qab", :job_title => "Superman"})
#    Alexandre Berman (sashka@lazybear.net)

class User
   attr_accessor :full_name, :password, :email, :login_name, :job_title

   def read_user key
      user_details = @suite.CONFIG["users"][key.to_s]
      {
         :full_name  => user_details["full_name"],
         :password   => user_details["password"].nil? ? "abcd1234" : user_details["password"],
         :email      => user_details["email"].nil? ? "#{user_details["login_name"]}@#{@suite.CONFIG['user_domain']}" : user_details["email"],
         :login_name => user_details["login_name"],
         :job_title  => user_details["job_title"]
      }
   end

   # -- default constructor creating user with default values
   def initialize(suite, options = {})
      @suite = suite
      # -- define our vars, overriding defaults if needed with options hash

      default_user = read_user :user1
      if options[:user]
        @config = default_user.merge(read_user options[:user])
      else
        @config = default_user.merge(options)
      end

      @full_name  = @config[:full_name]
      @password   = @config[:password]
      @email      = @config[:email]
      @login_name = @config[:login_name]
      @job_title  = @config[:job_title]
   end

   # -- first name guessing
   def first_name
      return /^([^\s]*)/.match(@full_name)[1]
   end

end
