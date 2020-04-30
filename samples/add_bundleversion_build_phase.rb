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
# COMMIT AND HASH TO PLIST
git=$(sh /etc/profile; which git)
commit=$("$git" rev-parse --short HEAD)
branch=$("$git" symbolic-ref HEAD 2>/dev/null)
plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
if [ -f "$plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :GIT_BRANCH_NAME $branch" "$plist"
    /usr/libexec/PlistBuddy -c "Set :GIT_COMMIT_HASH $commit" "$plist"

    # BUILD NUMBER FROM FASTLANE TO PLIST
    buildNumber="${ENV_BUILD_NUMBER}"
    if [ "${buildNumber}" != "" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "$plist"
    else
        buildNumber=$(date -n "+%Y%m%d%H%M")
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "$plist"
    fi

    root_plist="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Settings.bundle/Root.plist"
    if [ -f "$root_plist" ]; then
      echo "Updating Settings bundle."
      bundle_short_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${plist}" )
      build="${buildNumber} (${commit})"
      dirty_build=`git diff HEAD | wc -c | xargs`

      if [ "$dirty_build" != "0" ]
      then
        build="${build}/d"
      fi

      /usr/libexec/PlistBuddy -c "Set PreferenceSpecifiers:0:DefaultValue $bundle_short_version" "${root_plist}"
      /usr/libexec/PlistBuddy -c "Set PreferenceSpecifiers:1:DefaultValue $build" "${root_plist}"
    fi
fi
  HEREDOC
end

# Open project and add build phase
files = Dir.glob("*.xcodeproj")
if files.count == 0
    puts " No xcodeproj found in the current directory"
    puts " Nothing to do. Exiting"
    exit
end
project_path = files[0]
puts "Checking for existing targets in project " + project_path;
project = Xcodeproj::Project.open(project_path);
project.targets.each do |native_target|
    if native_target.product_type == "com.apple.product-type.application"
        puts " Checking target "+native_target.name + " (type " + native_target.product_type + ")"
        phase = create_or_update_build_phase(native_target, "Date Based CFBundleVersion")
        phase.shell_script = get_script
    end
end
project.save();
puts ""

# Put project back to json format
# puts "Touching project file to convert to json format"
# puts ""
# exec( "xcproj touch "+project_path )

## TODO: We may add GIT_BRANCH_NAME and GIT_COMMIT_HASH to apps plist
