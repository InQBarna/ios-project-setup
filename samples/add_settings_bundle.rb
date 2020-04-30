#!/usr/bin/ruby
#Add  -w at the end of ruby for warnings

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
Bundler.require('fileutils')

def get_root_plist
  <<-HEREDOC
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  	<key>PreferenceSpecifiers</key>
  	<array>
  		<dict>
  			<key>DefaultValue</key>
  			<string>0</string>
  			<key>Key</key>
  			<string>version_preference</string>
  			<key>Title</key>
  			<string>Version</string>
  			<key>Type</key>
  			<string>PSTitleValueSpecifier</string>
  		</dict>
      <dict>
        <key>Type</key>
        <string>PSTitleValueSpecifier</string>
        <key>DefaultValue</key>
        <string>0</string>
        <key>Title</key>
        <string>Build</string>
        <key>Key</key>
        <string>build_preference</string>
      </dict>
  	</array>
  	<key>StringsTable</key>
  	<string>Root</string>
  </dict>
  </plist>
  HEREDOC
end

## Crea el settings.bundle por defecto
group_name = 'Settings.bundle'
if !File.file?(group_name + '/Root.plist')
    unless File.directory?(group_name)
      puts 'Creating folder ' + group_name
      FileUtils.mkdir_p(group_name)
    end

    puts 'Creating ' + group_name + '/Root.plist'
    File.open(group_name + '/Root.plist', 'w') do |f|
      f.write(get_root_plist)
    end
else
    puts group_name + ' already created'
end

# Open project and add build phase
files = Dir.glob("*.xcodeproj")
if files.count == 0
    puts " No xcodeproj found in the current directory"
    puts " Nothing to do. Exiting"
    exit
end
project_path = files[0]
project = Xcodeproj::Project.open(project_path);

# Add settings.bundle to the project
group = project.main_group[group_name]
unless group
  puts "Adding " + group_name + " to project " + project_path;
  group = project.main_group.new_file(group_name)
else
  puts group_name + " group in project already created"
end

project.targets.each do |native_target|
  # Add to all targets ?? for now
  unless native_target.resources_build_phase.files_references.include?(group)
    puts "Adding copy resource phase to project " + project_path + " target " + native_target.name;
    native_target.add_resources([group])
  else
    puts "Copy resource phase already created on project " + project_path + " target " + native_target.name;
  end
end

project.save()
puts ""
