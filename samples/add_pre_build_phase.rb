#!/usr/bin/ruby
#Add  -w at the end of ruby for warnings

require 'xcodeproj'


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

# Open project and add build phase
project_path = "./ExpertusMuseumPlatform.xcodeproj";
puts "Checking for existing targets in project " + project_path;
project = Xcodeproj::Project.open(project_path);
project.targets.each do |native_target|
    if native_target.product_type == "com.apple.product-type.application"
        puts " Checking target "+native_target.name + " (type " + native_target.product_type + ")"
        phase = create_or_update_build_phase(native_target, "Pre build step")
        #script_path = target.embed_frameworks_script_relative_path
        #phase.shell_script = %("#{script_path}"\n)
        phase.shell_script = "echo Hola"
    end
end
project.save();
puts ""

# Put project back to json format
puts "Touching project file to convert to json format"
puts ""
exec( "xcproj touch "+project_path )
