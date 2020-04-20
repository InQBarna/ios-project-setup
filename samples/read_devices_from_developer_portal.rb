#!/usr/bin/env ruby
#Add  -w at the end of ruby for warnings

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

Spaceship.login

if !ENV["FASTLANE_TEAM_ID"]
  puts "No team provided"
end
Spaceship.select_team

devices = Spaceship.device.all

File.open("fastlane/devices.txt", "w") { |f|
  f.write "Device ID\tDevice Name\n"
  devices.each do |device|
      f.write "#{device.udid}\t#{device.name}\n"
  end
}
