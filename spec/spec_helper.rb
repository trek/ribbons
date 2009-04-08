spec_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift spec_dir unless $LOAD_PATH.include?(spec_dir)

lib_dir  = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)

begin
  require 'rubygems'
  require 'spec'
rescue
  require 'spec'
end

require 'kvo.rb'
