# -- The function of macros.rb is to allow you to create selections of scripts for common functions.
#
#    Alexandre Berman (sashka@lazybear.net)
Dir.new(dirname = File.join(File.dirname(__FILE__), "macro_impl")).entries.each do |rb|
  require File.join(dirname, rb) if rb =~/\.rb$/
end
