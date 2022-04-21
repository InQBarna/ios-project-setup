#!/usr/bin/env ruby
#Add  -w at the end of ruby for warnings

require 'rubygems'
require 'bundler/setup'
require 'spaceship'
Bundler.require(:default)

# not working... keys are not able to connect to dev portal ?
# puts "Do you want to provide a p8 key for login? (y/n)"
# prompt = STDIN.gets.chomp
# if prompt == 'y'
#   puts "Please enter the key id"
#   key_id = STDIN.gets
#   puts "Please enter the issuer id"
#   issuer_id = STDIN.gets
#   puts "Please enter the key path"
#   key_path = STDIN.gets
#
#   token = Spaceship::ConnectAPI::Token.create(
#     key_id: key_id,
#     issuer_id: issuer_id,
#     filepath:  File.absolute_path("./fastlane/AuthKey_RPQ62A8YFZ.p8")
#   )
#   Spaceship::ConnectAPI.token = token
# else
#   Spaceship.login
# end

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
