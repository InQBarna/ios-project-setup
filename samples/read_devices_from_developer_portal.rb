#!/usr/bin/ruby
#Add  -w at the end of ruby for warnings

require 'spaceship'

Spaceship.login

Spaceship.select_team

devices = Spaceship.device.all

puts "Device ID\tDevice Name"
devices.each do |device|
    puts "#{device.udid}\t#{device.name}"
end

