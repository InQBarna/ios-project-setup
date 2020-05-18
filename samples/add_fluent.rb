#!/usr/bin/ruby
#Add  -w at the end of ruby for warnings

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

# Method to add build phase
BUILD_PHASE_PREFIX = "[IQ] " 
def create_or_update_build_phase(target, phase_name, phase_class = Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  prefixed_phase_name = BUILD_PHASE_PREFIX + phase_name
  build_phases = target.build_phases.grep(phase_class)
  build_phases.find { |phase| phase.name && phase.name.end_with?(phase_name) }.tap { |p| p.name = prefixed_phase_name if p } ||
    target.project.new(phase_class).tap do |phase|
      puts "  Adding Build Phase '#{prefixed_phase_name}' to target "+target.name + " " + target.product_type
      phase.name = prefixed_phase_name
      phase.show_env_vars_in_log = '0'
      target.build_phases << phase
    end
end

def get_script 
  <<-HEREDOC
${PODS_ROOT}/Fluent/fluent
  HEREDOC
end

def get_l10n_file
  <<-HEREDOC
//
// Fluent.swift
//
// Copyright (c) 2020 InQBarna Kenkyuu Jo (http://inqbarna.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//swiftlint:disable identifier_name
import Foundation

func TR(_ key: String, _ text: String, comment: String) -> String {
    return __TR(key, text, comment: comment)
}

func TR(_ key: String, _ text: String) -> String {
    return __TR(key, text, comment: nil)
}

func TR(_ key: String) -> String {
    return __TR(key, nil, comment: nil)
}

func TRP(_ key: String, _ text: String, comment: String) -> String {
    return __TR(key, text, comment: comment)
}

func TRP(_ key: String, _ text: String) -> String {
    return __TR(key, text, comment: nil)
}

func TRP(_ key: String) -> String {
    return __TR(key, nil, comment: nil)
}

internal func __TR(_ key: String, _ text: String?, comment: String?) -> String {
    guard let text = text else {
        return NSLocalizedString(key, comment: comment ?? "")
    }
    return NSLocalizedString(text, comment: comment ?? "")
}

struct L10N {

}
  HEREDOC
end

## Crea el settings.bundle por defecto
group_name = 'L10N'
if !File.file?(group_name + '/L10N.swift')
    unless File.directory?(group_name)
      puts 'Creating folder ' + group_name
      FileUtils.mkdir_p(group_name)
    end

    puts 'Creating ' + group_name + '/L10N.swift'
    File.open(group_name + '/L10N.swift', 'w') do |f|
      f.write(get_l10n_file)
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

# Add settings.bundle to the project
group = project.main_group[group_name]
unless group
  puts "Adding " + group_name + " to project " + project_path;
  group = project.main_group.new_file(group_name)
else
  puts group_name + " group in project already created"
end

puts "Checking for existing targets in project " + project_path;
project = Xcodeproj::Project.open(project_path);
project.targets.each do |native_target|
  if native_target.product_type == "com.apple.product-type.application"
    puts " Checking target "+native_target.name + " (type " + native_target.product_type + ")"
    phase = create_or_update_build_phase(native_target, "Fluent checks")
    phase.shell_script = get_script
    unless native_target.resources_build_phase.files_references.include?(group)
      puts "Adding copy resource phase to project " + project_path + " target " + native_target.name;
      native_target.add_resources([group])
    else
      puts "Copy resource phase already created on project " + project_path + " target " + native_target.name;
    end
  end
end
project.save();
puts ""

# Put project back to json format
# puts "Touching project file to convert to json format"
# puts ""
# exec( "xcproj touch "+project_path )

## TODO: We may add GIT_BRANCH_NAME and GIT_COMMIT_HASH to apps plist
