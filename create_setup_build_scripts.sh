#! /bin/bash

# Version methods
version_less_than_or_equal() {
    [  "$1" == `echo -e "$1\n$2" | sort -V | head -n1` ]
}
version_less_than() {
    [ "$1" == "$2" ] && return 1 || version_less_than_or_equal $1 $2
}

# Writing Gemfile with cocoapods and fastlane
echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Creating Gemfile with fastlane, cocoapods, xcodeproj and slather (for coverage)"
GEMFILE=$(cat <<"EOF"
source "https://rubygems.org"

gem 'fastlane'
# Removed 2K23
# gem 'cocoapods' 
gem 'xcodeproj'
gem 'slather'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF
)
echo "$GEMFILE" > Gemfile

MIN_BUNDLER_VERSION="2.5.6"
MIN_RUBY_VERSION="3.3.0"
MIN_GEM_VERSION="3.5.3"

# Pre-checks
USER_BUNDLER_VERSION=`bundle --version | sed -e "s/.*\([0-9]\.[0-9]*\.[0-9]*\).*/\1/"`
BUNDLER_VERSION=$USER_BUNDLER_VERSION
version_less_than "$USER_BUNDLER_VERSION" "$MIN_BUNDLER_VERSION" && BUNDLER_VERSION="$MIN_BUNDLER_VERSION"
USER_RUBY_VERSION=`ruby --version | sed -e "s/.*\([0-9]\.[0-9]*\.[0-9]*\).*/\1/"`
RUBY_VERSION=$USER_RUBY_VERSION
version_less_than "$USER_RUBY_VERSION" "$MIN_RUBY_VERSION" && RUBY_VERSION="$MIN_RUBY_VERSION"

# Configure ruby (rbenv) GEMS
echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Setting up/configuring setup script with:"
echo " RUBY_VERSION      \"$RUBY_VERSION\" (rbenv)"
echo " MIN_GEM_VERSION   \"$MIN_GEM_VERSION\""
echo " BuNDLER_VERSION   \"$BUNDLER_VERSION\""
if [[ ! -d scripts ]]; then
    mkdir scripts
fi
SETUP_SH=$(cat <<"EOF"
#!/bin/sh
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Version methods
version_less_than_or_equal() {
    [  "$1" == `echo -e "$1\n$2" | sort -V | head -n1` ]
}
version_less_than() {
    [ "$1" == "$2" ] && return 1 || version_less_than_or_equal $1 $2
}

echo "[SETUP.SH] Checking brew"
eval $(/opt/homebrew/bin/brew shellenv)
if [[ `which brew` == "" ]]; then
    echo "[SETUP.SH] brew is necessary for installations, specially installing rbenv for ruby"
    echo "[SETUP.SH]  Please install it using: "
    echo "[SETUP.SH]   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)\""
    echo "[SETUP.SH]  Or follow instructions at https://brew.sh"
    exit -1
fi

echo "[SETUP.SH] Installing / checking xchtmlreport"
which xchtmlreport > /dev/null || brew install xctesthtmlreport
xchtmlreport --version | grep "^2\." || brew upgrade xctesthtmlreport
which xchtmlreport > /dev/null || echo "[SETUP.SH] WARNING: Could not install xchtmlreport"

echo "[SETUP.SH] Checking / installing ruby + gem + bundler"
export RUBY_VERSION=""
export BUNDLER_VERSION_MIN_GREP=" 2\.3"
export MIN_GEM_VERSION=""
if [[ `which rbenv` == "" ]]; then
    echo "[SETUP.SH] Installing rbenv"
    brew install rbenv
fi
version_less_than `gem --version` "$MIN_GEM_VERSION" && UPGRADE_GEM="yes" || UPGRADE_GEM="no"
if [[ "$UPGRADE_GEM" == "yes" ]]; then
  echo "[SETUP.SH] Upgrading gem executable"
  gem update --system
fi
which gem | grep ".rbenv" > /dev/null || eval "$(rbenv init -)"
rbenv versions | grep "$RUBY_VERSION" || rbenv install $RUBY_VERSION
rbenv local $RUBY_VERSION
ruby --version | grep "$RUBY_VERSION" || exit -1
gem env | grep "RUBY VERSION: $RUBY_VERSION" || exit -1
if [[ `which bundle` == "" ]]; then
    echo "Y" | gem uninstall -a bundler
    gem install --user-install bundler
fi
if [[ `bundle --version | grep "$BUNDLER_VERSION_MIN_GREP"` == "" ]]; then
    bundle update --bundler
fi
bundle install
#bundle clean

echo "[SETUP.SH] checking swiftlint installation"
if [[ `which swiftlint` == "" ]]; then
  echo "[SETUP.SH] Installing swiftlint"
  brew install swiftlint
end

# Use this if firebase is added as SPM
if [ ! -f "scripts/upload-symbols" ]; then
  echo "[SETUP.SH] Downloading upload-ymbols for crashlytics"
  curl "https://github.com/firebase/firebase-ios-sdk/raw/master/Crashlytics/upload-symbols" > scripts/upload-symbols
  chmod +x scripts/upload-symbols
fi

EOF
)
echo "$SETUP_SH" > scripts/setup.sh
sed -i "" -e "s/^export RUBY_VERSION=\"\"$/export RUBY_VERSION=\"$RUBY_VERSION\"/g" scripts/setup.sh
sed -i "" -e "s/^export BUNDLER_VERSION=\"\"$/export BUNDLER_VERSION=\"$BUNDLER_VERSION\"/g" scripts/setup.sh
sed -i "" -e "s/^export MIN_GEM_VERSION=\"\"$/export MIN_GEM_VERSION=\"$MIN_GEM_VERSION\"/g" scripts/setup.sh
chmod +x scripts/setup.sh
echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Running setup script without pod install"
scripts/setup.sh

# pod install added later to setup script...
echo "
# Removed 2K23
# echo \"[SETUP.SH] Runnig pod install\"
# bundle exec pod install || bundle exec pod install --repo-update || exit -1
" >> scripts/setup.sh


# build script
echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Searching for workspace file"
WORKSPACE_NAME=`find . -iname "*.xcworkspace" | grep -v ".xcodeproj/" | head -n 1 | sed -e "s/\.\///g" | sed "s/\.xcworkspace//g"`

# Removed 2K23, may be parametrized ?
# PODFILE=`find . -iname Podfile | head -n 1`
# if [[ $WORKSPACE_NAME == "" && $PODFILE == "" ]]; then
#   echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Could not find workspace file, will generate one by setting up pods"
#   bundle exec pod init
#   bundle exec pod install
# fi

# without pods, search for workspace inside xcodeproj
if [[ $WORKSPACE_NAME == "" ]]; then
  WORKSPACE_NAME=`find . -iname "*.xcworkspace" | head -n 1 | sed -e "s/\.\///g" | sed "s/\.xcworkspace//g"`
fi

if [[ $WORKSPACE_NAME == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Could not find workspace file, build script won't be generated"
  exit -1
fi

echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Setting up/configuring build script with:"
echo " RUBY_VERSION      \"$RUBY_VERSION\" (rbenv)"
echo " MIN_GEM_VERSION   \"$MIN_GEM_VERSION\""
echo " BuNDLER_VERSION   \"$BUNDLER_VERSION\""
echo " WORKSPACE_NAME    \"$WORKSPACE_NAME\""
PROJECT_NAME=`find . -iname *.xcodeproj | head -n 1 | sed -e "s/\.\///g" | sed -e "s/\.xcodeproj//g"`
if [[ $PROJECT_NAME == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Could not find project file, build script won't be generated"
  exit -1
fi
echo " PROJECT_NAME    \"$WORKSPACE_NAME\""
SCHEME_FILE=`find $WORKSPACE_NAME.xcworkspace -iname *.xcscheme | grep "xcshareddata/xcschemes" | head -n 1`
if [[ "$SCHEME_FILE" != "" ]]; then
  SCHEME=`echo $SCHEME_FILE | sed -e "s/.*[/]\([^/]*\)\.xcscheme/\1/g"` 
else
  SCHEME=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Schemes/,/^$/p' | grep -v "Tests" | grep -v "^$" | grep -v "Schemes:" | sed -e "s/^[ ]*//g" | head -n 1`
fi
if [[ "$SCHEME_FILE" != "" ]]; then
  echo " SCHEME_FILE       \"$SCHEME_FILE\""
fi
if [[ "$SCHEME" == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Error: Could not find a valid scheme"
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Build script won't be generated"
  exit -1
fi
echo " SCHEME            \"$SCHEME\""
MAIN_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep -v "Tests" | grep -v "^$" | grep -v "Targets:" | sed -e "s/^[ ]*//g" | head -n 1`
if [[ "$MAIN_TARGET" == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Could not find main app target"
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Build script won't be generated"
  exit -1
fi
echo " MAIN_TARGET       \"$MAIN_TARGET\""
TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "[^U][^I]Tests" | sed -e "s/ *\([a-zA-Z ]*\)/\1/g" | head -n 1`
if [[ "$TEST_TARGET" == "" ]]; then
  TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "Tests" | sed -e "s/ *\([a-zA-Z ]*\)/\1/g" | head -n 1`
  if [[ "$TEST_TARGET" == "" ]]; then
    TEST_TARGET="${MAIN_TARGET}Tests"
    echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] There's no test target in your project, will use ${TEST_TARGET} for testing purposes... but running tests won't work until you create it"
  fi
fi
echo " TEST_TARGET       \"$TEST_TARGET\""
UI_TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "UITests" | sed -e "s/^[ ]*//g" | head -n 1`
if [[ "$UI_TEST_TARGET" == "" ]]; then
  UI_TEST_TARGET="${MAIN_TARGET}UITests"
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] There's no test target in your project, you can create a target named ${MAIN_TARGET}UITests later if you want to run ui test separately"
else
  echo " UI_TEST_TARGET    \"$UI_TEST_TARGET\""
fi
if [[ "$SCHEME_FILE" == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Warning: There's no shared scheme on your workspace, for others to be able to build the same project you need a shared scheme in the workspace"
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] You may have schemes set up on your project, please avoid this. Schemes should be added to workspace!!"
else
  if [[ `git status $SCHEME_FILE | grep Untracked | wc -l` -gt 0 ]]; then
    echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Warning: The file $SCHEME_FILE should be added to the version control system"
  fi
fi

BUILD_SH=$(cat <<"EOF"
#!/bin/sh

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export RUBY_VERSION=""
export BUNDLER_VERSION_MIN_GREP=" 2\."

echo "[BUILD.SH] Configuring ruby and checking bundler version"
eval $(/opt/homebrew/bin/brew shellenv)
which gem | grep ".rbenv" || eval "$(rbenv init -)"
bundle --version | grep "$BUNDLER_VERSION_MIN_GREP" || (echo "[BUILD.SH] Failed to find bundle version above ${BUNLDER_VERION_MIN_GREP}" && exit -1)
ruby --version | grep "$RUBY_VERSION" || (echo "[BUILD.SH] Failed to find ruby version  ${RUBY_VERSION}" && exit -1)
gem env | grep "RUBY VERSION: $RUBY_VERSION" || (echo "[BUILD.SH] Failed to find gem configured with version  ${RUBY_VERSION}" && exit -1)

echo "[BUILD.SH] checking outdated provisioning profiles"
echo "[BUILD.SH] TODO: use remove_provisioning_profile plugin in fastelane"
for provisioning_profile in ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision;
do
  expirationDate=`/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' /dev/stdin <<< $(security cms -D -i "${provisioning_profile}")`
  timestamp_expiration=`date -jf"%a %b %d %T %Z %Y" "${expirationDate}" +%s`
  timestamp_now=`date +%s`
  if [ ${timestamp_now} -ge ${timestamp_expiration} ]; then
    echo "[BUILD.SH] removing outdated \"${provisioning_profile}\""
    rm -f "${provisioning_profile}"
  fi
done

if [[ $INTENT == "appstore" ]]; then

  echo "[BUILD.SH] Uploading to appstore using fastlane"
  bundle exec fastlane beta

elif [[ $INTENT == "firebase" ]]; then

  echo "[BUILD.SH] Uploading to firebase using fastlane"
  if [[ `which firebase` == "" ]]; then
    echo "[BUILD.SH] Did not find or install firebase cli, setup.sh should have installed it"
  fi

  echo "[BUILD.SH] Uploading to firebase using fastlane"
  # upload-symbols should be located in the project folder by setup.sh script in ci/cd machine, however you can also...
  # Use this is firebase is added as SPM
  # export UPLOAD_SYMBOLS_PATH=`xcodebuild -showBuildSettings | grep -m 1 "BUILD_DIR" | grep -oEi "\/.*" | sed 's/Build\/Products/SourcePackages\/checkouts\/firebase-ios-sdk\/Crashlytics\/upload-symbols/'`
  # echo "Found UPLOAD_SYMBOLS_PATH at $UPLOAD_SYMBOLS_PATH"
  bundle exec fastlane firebase

elif [[ $INTENT == "test" ]]; then

  echo "[BUILD.SH] [`date +"%H:%M:%S"`] Running app TEST lane"
  bundle exec fastlane test

else

  echo "[BUILD.SH] [`date +"%H:%M:%S"`] Building app BUILD lane"
  bundle exec fastlane build

fi

EOF
)

echo "$BUILD_SH" > scripts/build.sh
sed -i "" -e "s/^export RUBY_VERSION=\"\"$/export RUBY_VERSION=\"$RUBY_VERSION\"/g" scripts/build.sh
sed -i "" -e "s/^  WORKSPACE_NAME=\"\"$/  WORKSPACE_NAME=\"$WORKSPACE_NAME\"/g" scripts/build.sh
sed -i "" -e "s/^  PROJECT_NAME=\"\"$/  PROJECT_NAME=\"$PROJECT_NAME\"/g" scripts/build.sh
sed -i "" -e "s/^  SCHEME=\"\"$/  SCHEME=\"$SCHEME\"/g" scripts/build.sh
sed -i "" -e "s/^  TEST_TARGET=\"\"$/  TEST_TARGET=\"$TEST_TARGET\"/g" scripts/build.sh
sed -i "" -e "s/^  UI_TEST_TARGET=\"\"$/  UI_TEST_TARGET=\"$UI_TEST_TARGET\"/g" scripts/build.sh
SAFE_PROJECT_NAME=`echo "$PROJECT_NAME" | tr -cd "[:alnum:]\n"`
sed -i "" -e "s/export KEYCHAIN_NAME=\"\"/export KEYCHAIN_NAME=\"$SAFE_PROJECT_NAME\"/g" scripts/build.sh

chmod +x scripts/build.sh

FASTFILE=$(cat <<"EOF"

import_from_git(url: 'https://github.com/InQBarna/xcode-scripts',
               path: 'fastlane/CommonFastfile')

default_platform(:ios)

DEVICE = ENV['DEVICE'] ? ENV['DEVICE'] : "iPhone 15 Pro"
RUNTIME = ENV['RUNTIME'] ? ENV['RUNTIME'] : "17.2"
XCODE_EXTRA_PATH = ENV['XCODE_EXTRA_PATH'] ? ENV['XCODE_EXTRA_PATH'] : "-15.2.0"

before_all do |lane, options|
    
    # Checking parameters
    xcode_select("/Applications/Xcode" + XCODE_EXTRA_PATH + ".app")
    if lane.name != 'test' && lane.name != 'build'
      unless ENV.key?('MATCH_PASSWORD')
        UI.message("MATCH_PASSWORD not set.  This may fail in cicd env")
      end
    else
      UI.message("Using " + DEVICE + ", " + RUNTIME + " as destination")
    end

    app_store_connect_api_key(
      key_id: "",
      issuer_id: "",
      key_filepath: "./fastlane/AuthKey_XXXXXXX.p8",
      in_house: false,
    )
end

platform :ios do

  lane :renuke do
    
    match_nuke(type: "development")
    match_nuke(type: "adhoc")
    match_nuke(type: "appstore")
  end

  lane :test do
    scan(
      scheme: "###",
      configuration: "Debug",
      destination: "platform=iOS Simulator,name=" + DEVICE + ",OS=" + RUNTIME,
      buildlog_path: "gymbuildlog",
      clean: true,
      derived_data_path: "deriveddata",
      code_coverage: true,
      force_quit_simulator: true,
      result_bundle: true,
      ensure_devices_found: true,
      fail_build: false,
      include_simulator_logs: true,
      parallel_testing: false
    )
    slather(
      cobertura_xml: true,
      output_directory: "coverage",
      ignore: ["Pods/*", "*/SourcePackages/*"],
      build_directory: "deriveddata",
      scheme: "###",
      proj: "iSocial.xcodeproj",
      use_bundle_exec: true
    )
    brew_path = sh("brew --prefix xctesthtmlreport").gsub("\n", "")
    binary_path = File.join(brew_path, "bin", "xchtmlreport")
    xchtmlreport(
      enable_junit: true,
      binary_path: binary_path
    )
    UI.message("All files below are kept for CI/CD post-ooperations, you may want to delete them in local run")
    UI.message("Build data at folder\"gymbuildlog/*-*.log\"")
    UI.message("Build log generated at \"gymbuildlog/*-*.log\"")
    UI.message("Derived data at folder \"deriveddata\"")
    UI.message("Test output generated at folder \"fastlane/test_output\"")
    UI.message("Coverage data at folder \"coverage\"")
  end

  lane :build do
    gym(
      scheme: "###",
      configuration: "Debug",
      destination: "platform=iOS Simulator,name=" + DEVICE + ",OS=" + RUNTIME,
      buildlog_path: "gymbuildlog",
      clean: true,
      derived_data_path: "deriveddata",
      skip_archive: true,
      skip_package_ipa: true
    )
    UI.message("All files below are kept for CI/CD post-ooperations, you may want to delete them in local run")
    UI.message("Build data at folder\"gymbuildlog/*-*.log\"")
    UI.message("Build log generated at \"gymbuildlog/*-*.log\"")
    UI.message("Derived data at folder \"deriveddata\"")
  end

  desc "Submit a new Test Build to Firebase"
  desc "This will also make sure the profile is up to date"
  lane :firebase do
    # This method from include does most of the job
    iq_firebase_v2(schemename: "###",
                  appname: "###",
                  targetname: "###",
                  configuration: "Release",
                  xcprojname: "###",
                  bundleid: "###.###.###",
                  firebaseid: "1:###:ios:###",
                  testers_cs: "")
  end

  desc "Submit a new Beta Build to Apple Apple TestFlight"
  desc "This will also make sure the profile is up to date"
  lane :beta do
    iq_beta(appname: "###",
            schemename: "###",
            targetname: "###",
            configuration: "Release",
            xcprojname: "###",
            bundleid: "###.###.###")
  end
end

EOF
)

if [ ! -d fastlane ]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Setting up fastlane with"
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Please provide the team id from developer portal"
  read TEAM_ID
  echo " TEAM_ID           \"$TEAM_ID\""
  BUNDLE_ID=`xcodebuild -showBuildSettings --scheme="$SCHEME" -target "$MAIN_TARGET" | grep PRODUCT_BUNDLE_IDENTIFIER | sed -e "s/ *PRODUCT_BUNDLE_IDENTIFIER = \(.*\)$/\1/g"`
  echo " BUNDLE_ID         \"$BUNDLE_ID\""
  PRODUCT_NAME=`xcodebuild -showBuildSettings --scheme="$SCHEME" -target "$MAIN_TARGET" | grep FULL_PRODUCT_NAME | sed -e "s/ *FULL_PRODUCT_NAME = \(.*\)\.app$/\1/g"`
  echo " PRODUCT_NAME      \"$PRODUCT_NAME\""
  mkdir fastlane
  echo "$FASTFILE" > fastlane/Fastfile
  sed -i "" -e "s/appname: \"###\"/appname: \"$PRODUCT_NAME\"/g" fastlane/Fastfile
  sed -i "" -e "s/schemename: \"###\"/schemename: \"$SCHEME\"/g" fastlane/Fastfile
  sed -i "" -e "s/scheme: \"###\"/scheme: \"$SCHEME\"/g" fastlane/Fastfile
  sed -i "" -e "s/targetname: \"###\"/targetname: \"$MAIN_TARGET\"/g" fastlane/Fastfile
  sed -i "" -e "s/xcprojname: \"###\"/xcprojname: \"$PROJECT_NAME\"/g" fastlane/Fastfile
  sed -i "" -e "s/bundleid: \"###.###.###\"/bundleid: \"$BUNDLE_ID\"/g" fastlane/Fastfile

  echo "app_identifier \"$BUNDLE_ID\"" > fastlane/Appfile
  echo "team_id \"$TEAM_ID\"" >> fastlane/Appfile
fi

if [ ! -f fastlane/Matchfile ]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Switching to setup_match.sh"
  curl -fsSL http://gitlab.inqbarna.com/contrib/xcode-scripts/-/raw/master/samples/setup_match.sh > /tmp/setup_match.sh
  chmod +x /tmp/setup_match.sh
  /tmp/setup_match.sh
fi

bundle exec fastlane add_plugin firebase_app_distribution
bundle exec fastlane add_plugin xchtmlreport
bundle exec fastlane add_plugin remove_provisioning_profilegit@github.com:InQBarna/ios-match.git

FOUND_SCRIPT=`grep "BUILD NUMBER FROM FASTLANE TO PLIST" "$PROJECT_NAME.xcodeproj/project.pbxproj"`
if [[ $FOUND_SCRIPT == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Switching to add_bundleversion_build_phase.rb"
  curl -fsSL http://gitlab.inqbarna.com/contrib/xcode-scripts/-/raw/master/samples/add_bundleversion_build_phase.rb > /tmp/add_bundleversion_build_phase.rb
  chmod +x /tmp/add_bundleversion_build_phase.rb
  bundle exec ruby /tmp/add_bundleversion_build_phase.rb
else
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Build phase that includes build number to apps plist already found in project"
fi

echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Settting up gitignore"
curl -s "https://www.toptal.com/developers/gitignore/api/xcode,swift,macos,swiftpackagemanager,swiftpm" > .gitignore
sed -i "" -e "/^\*\.xcodeproj$/d" .gitignore
echo "Pods" >> .gitignore
echo "fastlane/README.md" >> .gitignore
echo "fastlane/test_output_ui" >> .gitignore
echo "firebase" >> .gitignore
echo "coverage" >> .gitignore
echo "scripts/upload-symbols" >> .gitignore
echo "*.p8" >> .gitignore
