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
gem 'cocoapods'
gem 'xcodeproj'
gem 'slather'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
EOF
)
echo "$GEMFILE" > Gemfile

# Pre-checks
USER_BUNDLER_VERSION=`bundle --version | sed -e "s/.*\([0-9]\.[0-9]*\.[0-9]*\).*/\1/"`
BUNDLER_VERSION=$USER_BUNDLER_VERSION
version_less_than "$USER_BUNDLER_VERSION" "2.2.21" && BUNDLER_VERSION="2.2.21"

# Configure ruby (rbenv) GEMS
RUBY_VERSION="2.7.2"
MIN_GEM_VERSION="3.2.20"
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
if [[ `which brew` == "" ]]; then
    echo "[SETUP.SH] brew is necessary for installations, specially installing rbenv for ruby"
    exit -1
fi

echo "[SETUP.SH] Installing / checking xchtmlreport"
which xchtmlreport || brew install https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/develop/xchtmlreport.rb
xchtmlreport -v | grep " 2\." || brew upgrade https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/develop/xchtmlreport.rb
which xchtmlreport || echo "[SETUP.SH] WARNING: Could not install xchtmlreport"

echo "[SETUP.SH] Checking / installing ruby + gem + bundler"
export RUBY_VERSION=""
export BUNDLER_VERSION=""
export MIN_GEM_VERSION=""
export PATH=/usr/local/bin/:$PATH
if [[ `which rbenv` == "" ]]; then
    echo "[SETUP.SH] Installing rbenv"
    brew install rbenv
fi
version_less_than `gem --version` "$MIN_GEM_VERSION" && UPGRADE_GEM="yes" || UPGRADE_GEM="no"
if [[ "$UPGRADE_GEM" == "yes" ]]; then
  echo "[SETUP.SH] Upgrading gem executable"
  gem update --system
fi
which gem | grep ".rbenv" || eval "$(rbenv init -)"
rbenv versions | grep "$RUBY_VERSION" || rbenv install $RUBY_VERSION
rbenv local $RUBY_VERSION
ruby --version | grep "$RUBY_VERSION" || exit -1
gem env | grep "RUBY VERSION: $RUBY_VERSION" || exit -1
if [[ `bundle --version | grep "$BUNDLER_VERSION"` == "" ]]; then
    echo "Y" | gem uninstall -a bundler
    gem install --user-install bundler:$BUNDLER_VERSION
fi
if [[ `bundle --version | grep "$BUNDLER_VERSION"` == "" ]]; then
  echo "[SETUP.SH] Could not install bundler version \"$BUNDLER_VERSION\""
  exit -1
fi
bundle install
#bundle clean

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
echo \"[SETUP.SH] Runnig pod install\"
bundle exec pod install || bundle exec pod install --repo-update || exit -1
" >> scripts/setup.sh


# build script
WORKSPACE_NAME=`find . -iname *.xcworkspace | grep -v ".xcodeproj/" | head -n 1 | sed -e "s/\.\///g" | sed -e "s/\.xcworkspace//g"`
PODFILE=`find . -iname Podfile | head -n 1`
if [[ $WORKSPACE_NAME == "" && $PODFILE == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Could not find workspace file, will generate one by setting up pods"
  bundle exec pod init
  bundle exec pod install
fi
WORKSPACE_NAME=`find . -iname *.xcworkspace | head -n 1 | sed -e "s/\.\///g" | sed -e "s/\.xcworkspace//g"`
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
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Could not find workspace file, build script won't be generated"
  exit -1
fi
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
export BUNDLER_VERSION=""
export PATH=/usr/local/bin/:$PATH
if [ "$XCODE_EXTRA_PATH" == "" ]; then
    export XCODE_EXTRA_PATH=""
fi
export XCODE_PATH="/Applications/Xcode$XCODE_EXTRA_PATH.app/"
export DEVELOPER_DIR="$XCODE_PATH/Contents/Developer/"
if [ "$RUNTIME" == "" ]; then
    export RUNTIME="15.2"
fi
export DEVICE="iPhone 11"
echo "[BUILD.SH] Using xcode at $XCODE_PATH. (Use XCODE_EXTRA_PATH to change it)"

echo "[BUILD.SH] Checking input parameters"
if [ "$INTENT" == "appstore" ] || [ "$INTENT" == "firebase" ]; then
  if [[ "$KEYCHAIN_PASSWORD" == "" ]]; then
    echo "[BUILD.SH] Missing KEYCHAIN_PASSWORD env variable, configure jenkins bindings or please use:"
    echo "[BUILD.SH] export KEYCHAIN_PASSWORD=XXX"
    exit -1
  fi
  if [[ "$MATCH_PASSPHRASE" == "" ]]; then
    echo "[BUILD.SH] Missing MATCH_PASSPHRASE env variable, configure jenkins bindings or please use:"
    echo "[BUILD.SH] export MATCH_PASSPHRASE=XXX"
    exit -1
  fi
fi

echo "[BUILD.SH] Configuring ruby and checking bundler version"
which gem | grep ".rbenv" || eval "$(rbenv init -)"
bundle --version | grep "$BUNDLER_VERSION" || exit -1
ruby --version | grep "$RUBY_VERSION" || exit -1
gem env | grep "RUBY VERSION: $RUBY_VERSION" || exit -1
bundle --version | grep "$BUNDLER_VERSION" || exit -1

WORKSPACE_NAME=""
PROJECT_NAME=""
SCHEME=""
TEST_TARGET=""
UI_TEST_TARGET=""

if [ "$INTENT" == "appstore" ] || [ "$INTENT" == "firebase" ] || [ "$INTENT" == "browserStack" ]; then

  echo "[BUILD.SH] Cleaning derived data"
  bundle exec fastlane action clear_derived_data


  #
  # Setup keychain
  # 
  echo "[BUILD.SH] Setting up keychain with match profiles"
  export KEYCHAIN_NAME="musclemixer"
  [ ! -f ~/Library/Keychains/$KEYCHAIN_NAME-db ] &&  security create-keychain -p $KEYCHAIN_PASSWORD "$KEYCHAIN_NAME"
  security -v unlock-keychain -p "$KEYCHAIN_PASSWORD" ~/Library/Keychains/$KEYCHAIN_NAME-db
  echo "[BUILD.SH] Using keychain \"$KEYCHAIN_NAME\", and unlocking it for build"
  security list-keychains -d user -s ~/Library/Keychains/$KEYCHAIN_NAME-db
  security set-keychain-settings ~/Library/Keychains/$KEYCHAIN_NAME-db
  cleanupKeychain() {
    echo "[BUILD.SH] Cleanup keychain"
    security list-keychains -d user -s ~/Library/Keychains/login.keychain-db
  }

  #
  # Setup gym
  # 
  if [[ `cat fastlane/Gymfile | grep OTHER_XCODE_SIGN_FLAGS | wc -l` == 1 ]]; then
    echo "[BUILD.SH] Gymfile with OTHER_XCODE_SIGN_FLAGS not supported by this script, please report the issue if necessary"
    exit -1
  fi
  echo "xcargs \"OTHER_CODE_SIGN_FLAGS=--keychain=\\\"~/Library/Keychains/$KEYCHAIN_NAME-db\\\"\"" > fastlane/Gymfile

  # setup git creds
  if [ "$GIT_HTTPS_USER" != "" ] && [ "$GIT_HTTPS_PASSWORD" == "" ]; then
    ORIGIN=`git config -l | grep remote.origin.url | sed -e "s/remote.origin.url=//" | sed -e "s/:\/\/.*@/:\/\//g"`
    ORIGIN_WITH_CREDS=`echo $ORIGIN | sed -e "s/:\/\//:\/\/$GIT_HTTPS_USER:$GIT_HTTPS_PASSWORD@/g"`
  else
    ORIGIN_WITH_CREDS=`git config -l | grep remote.origin.url | sed -e "s/remote.origin.url=//" | sed -e "s/:\/\/.*@/:\/\//g"`
  fi

  #
  # Setup git creds for match and fastlane
  # 
  export MATCH_PASSWORD="$MATCH_PASSPHRASE"
  if [ "$GIT_HTTPS_USER" != "" ] && [ "$GIT_HTTPS_PASSWORD" == "" ]; then
    sed -i "" -e "s/http:\/\/gitlab.inqbarna.com/http:\/\/$GIT_HTTPS_USER:$GIT_HTTPS_PASSWORD@gitlab.inqbarna.com/" fastlane/Matchfile
  fi
  cleanupGym() {
    echo "[BUILD.SH] Cleanup Gym"
    sed -i "" -e "/OTHER_CODE_SIGN_FLAGS.*/d" fastlane/Gymfile
    if [[ `cat fastlane/Gymfile` == "" ]];
     # Removing Gymfile since we created it!
     then rm fastlane/Gymfile
    fi
    unset DEVELOPER_DIR
    git checkout fastlane/Matchfile
  }

  if [[ $INTENT == "appstore" ]]; then
    bundle exec fastlane match appstore --readonly --keychain_password $KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
    bundle exec fastlane match adhoc --readonly --keychain_password $KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"

    echo "[BUILD.SH] Uploading to appstore using fastlane"
    # Use this is firebase is added as SPM
    # export UPLOAD_SYMBOLS_PATH=`xcodebuild -showBuildSettings | grep -m 1 "BUILD_DIR" | grep -oEi "\/.*" | sed 's/Build\/Products/SourcePackages\/checkouts\/firebase-ios-sdk\/Crashlytics\/upload-symbols/'`
    # echo "Found UPLOAD_SYMBOLS_PATH at $UPLOAD_SYMBOLS_PATH"
    git remote set-url origin $ORIGIN_WITH_CREDS
    bundle exec fastlane beta
    git remote set-url origin $ORIGIN

  elif [[ $INTENT == "firebase" ]]; then

    echo "[BUILD.SH] Uploading to firebase using fastlane"
    if [[ `which firebase` == "" ]]; then
        export FIREBASE_PATH=`pwd`/firebase
        ./firebase --version || curl -L "https://firebase.tools/bin/macos/latest" --output firebase && chmod +x firebase && ./firebase --version
        if [[ `which firebase` == "" ]]; then
          export PATH=$PATH:`pwd`
        fi
        if [[ `which firebase` == "" ]]; then
           echo "[BUILD.SH] Could not find or install firebase cli"
           exit
        fi
    fi

    bundle exec fastlane match adhoc --readonly --keychain_password $KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
    # Use this is firebase is added as SPM
    # export UPLOAD_SYMBOLS_PATH=`xcodebuild -showBuildSettings | grep -m 1 "BUILD_DIR" | grep -oEi "\/.*" | sed 's/Build\/Products/SourcePackages\/checkouts\/firebase-ios-sdk\/Crashlytics\/upload-symbols/'`
    # echo "Found UPLOAD_SYMBOLS_PATH at $UPLOAD_SYMBOLS_PATH"
    git remote set-url origin $ORIGIN_WITH_CREDS
    bundle exec fastlane firebase
    git remote set-url origin $ORIGIN
  fi

  #
  # Common cleanup (Gym)
  # 
  cleanupKeychain
  cleanupGym
  
else

  DERIVEDDATA="deriveddata"
  # DERIVEDDATA="deriveddata$BUILD_NUMBER" # in case we need per-build derived data
  cleanBuildDirectory() {
    rm -Rf "$DERIVEDDATA"
    rm -Rf gymbuildlog
  }

  if [[ $INTENT == "test" ]]; then
    #
    # Simulator build and cleanup
    # 
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Checking/creating a simulator ($DEVICE - $RUNTIME)"
    if [ "$BUILD_NUMBER" == "" ]; then
      echo "[BUILD.SH] No jenkins environment found (BUILD_NUMBER), so no script-specific simulator will be created"
      simulatorName="$DEVICE"
    else
      if [ "$JOB_NAME" == "" ]; then
        simulatorName="$DEVICE - $JOB_NAME - ${BUILD_NUMBER: -1}"
      else
        simulatorName="$DEVICE - ${BUILD_NUMBER: -1}"
      fi
    fi
    simulatorUUID=`xcrun simctl list | sed -n "/-- iOS $RUNTIME --/,/-- /p" | grep "$simulatorName (" | sed -e "s/$simulatorName [(]\([^)]*\).*/\1/"`
    if [[ "$simulatorUUID" == "" ]]; then 
      echo "[BUILD.SH] Will create simulator \"$simulatorName\""
      RUNTIME_TYPE=`xcrun simctl list | sed -n '/== Runtimes ==/,/== /p' | grep "iOS $RUNTIME (" | sed -e "s/.*) - \(.*\)/\1/"`
      if [[ "$RUNTIME_TYPE" == "" ]]; then
        echo "[BUILD.SH] Could not find installed runtime $RUNTIME. Aborting"
        echo "[BUILD.SH] run \"xcrun simctl list\" and double check $RUNTIME is NOT available"
        exit -1
      fi
      DEVICE_TYPE=`xcrun simctl list | sed -n '/== Device Types ==/,/== /p' | grep "$DEVICE (" | sed -e "s/$DEVICE [(]\([^)]*\).*/\1/"`
      if [[ "$DEVICE_TYPE" == "" ]]; then
        echo "[BUILD.SH] Could not find device type $DEVICE. Aborting"
        echo "[BUILD.SH] run \"xcrun simctl list\" and double check $DEVICE is NOT available"
        exit -1
      fi
      echo "[BUILD.SH] Creating device $simulatorName ($DEVICE_TYPE) with runtime $RUNTIME ($RUNTIME_TYPE)"
      xcrun simctl create "$simulatorName" "$DEVICE_TYPE" "$RUNTIME_TYPE"
      echo "xcrun simctl create \"$simulatorName\" \"$DEVICE_TYPE\" \"$RUNTIME_TYPE\""
      simulatorUUID=`xcrun simctl list | sed -n "/-- iOS $RUNTIME --/,/-- /p" | grep "$simulatorName (" | sed -e "s/$simulatorName [(]\([^)]*\).*/\1/"`
      if [[ "$simulatorUUID" == "" ]]; then 
        echo "[BUILD.SH] Failed to create $simulatorName, aborting"
        exit -1
      fi
    else
      echo "[BUILD.SH] Found $simulatorName, resetting  state and removing previous data"
      xcrun simctl shutdown $simulatorUUID
      xcrun simctl erase $simulatorUUID
    fi
    removeCreatedSimulator() {
      if [[ "$BUILD_NUMBER" == "" || "$DO_NOT_DELETE_SIMULATOR" != "" ]]; then
        echo "[BUILD.SH] $simulatorName not deleted"
      else
        echo "[BUILD.SH] Delete created $simulatorName"
        xcrun simctl shutdown $simulatorUUID || true
        xcrun simctl delete $simulatorUUID
      fi
    }

    #
    # Building app for testing
    # 
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Building app for testing"
    cleanBuildDirectory
    bundle exec fastlane gym --workspace "./$WORKSPACE_NAME.xcworkspace" --scheme "$SCHEME" --skip_archive --configuration Debug --destination="platform=iOS Simulator,name=$simulatorName,OS=$RUNTIME" --skip_package_ipa true --buildlog_path gymbuildlog --xcargs "clean build-for-testing" --derived_data_path="$DERIVEDDATA"
    if [ $? -ne 0 ]; then
      removeCreatedSimulator
      cleanBuildDirectory
      exit -1
    fi

    #
    # Checking for warnings
    # 
    MAX_WARNINGS=0
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Checking for $MAX_WARNINGS warnings"
    WARNINGS=`egrep '^(/.+:[0-9+:[0-9]+:.(warning):|fatal|===)' "gymbuildlog/$PROJECT_NAME-$SCHEME.log" | uniq`
    NUM_WARNINGS=`echo $WARNINGS | egrep "(warning|fatal|===)" | wc -l`
    if [[ "$NUM_WARNINGS" -gt "$MAX_WARNINGS" ]]; then
      echo "There are $NUM_WARNINGS warnings, invalid build (max allowed warnings $MAX_WARNINGS"
      echo $WARNINGS
      removeCreatedSimulator
      cleanBuildDirectory
      exit -1
    fi
    echo "Nice,$NUM_WARNINGS warnings"

    #
    # Run unit tests
    # 
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Running unit tests"
    bundle exec fastlane scan --test_without_building="true" --devices="$DEVICE ($RUNTIME)" --scheme="$SCHEME" --code_coverage="true" --clean="false" --only_testing="$TEST_TARGET" --derived_data_path="$DERIVEDDATA"
    if [ $? -ne 0 ]; then
      removeCreatedSimulator
      cleanBuildDirectory
      exit -1
    fi
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Building code coverage result"
    bundle exec slather coverage --cobertura-xml --output-directory coverage --ignore "Pods/*" --ignore "*/SourcePackages/*" --build-directory="$DERIVEDDATA" --scheme "$SCHEME" --workspace "$WORKSPACE_NAME.xcworkspace" "$PROJECT_NAME.xcodeproj"

    #
    # Run ui tests
    # 
    rm -Rf fastlane/test_output_ui/*
    if [[ "$UI_TEST_TARGET" == "" ]]; then
      if [[ "$*" != "--no-concurrent" ]]; then
        echo "[BUILD.SH] [`date +"%H:%M:%S"`] Running UI tests concurrently"
        bundle exec fastlane scan --test_without_building="true" --code_coverage="false" --clean="false" --only_testing="$UI_TEST_TARGET" --output_directory="fastlane/test_output_ui/" --result_bundle="true" --xcargs="-parallel-testing-enabled YES -parallel-testing-worker-count 3" --destination="platform=iOS Simulator,name=$simulatorName,OS=$RUNTIME" --devices="${simulatorName} ($RUNTIME)" --derived_data_path="$DERIVEDDATA" --disable_xcpretty || true
        echo "[BUILD.SH] [`date +"%H:%M:%S"`] Building junit result with xchtml from files at"
        xchtmlreport -r "./fastlane/test_output_ui/$PROJECT_NAME.xcresult" -j
        cp "fastlane/test_output_ui/$PROJECT_NAME.xcresult/report.junit" "fastlane/test_output_ui/report.junit"
        sed -i "" -e "s/ - $simulatorName - $RUNTIME//g" "fastlane/test_output_ui/report.junit"
      else
        echo "[BUILD.SH] [`date +"%H:%M:%S"`] Running UI tests"
        bundle exec fastlane scan --test_without_building="true" --code_coverage="false" --clean="false" --only_testing="$UI_TEST_TARGET" --output_directory="fastlane/test_output_ui/" --result_bundle="true" --xcargs="--parallel-testing-enabled NO" --destination="platform=iOS Simulator,name=$simulatorName,OS=$RUNTIME" --devices="${simulatorName} ($RUNTIME)" --derived_data_path="$DERIVEDDATA" || true
        echo "[BUILD.SH] [`date +"%H:%M:%S"`] Building junit result with xchtml from files at"
        xchtmlreport -r "./fastlane/test_output_ui/$PROJECT_NAME.xcresult" -j
      fi
    else
      touch fastlane/test_output_ui/report.junit 
    fi

    #
    # Cleanup simulator
    # 
    removeCreatedSimulator
    cleanBuildDirectory

  else

    #
    # Building app
    # 
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Building app for testing"
    simulatorName="$DEVICE"
    cleanBuildDirectory
    bundle exec fastlane gym --workspace "./$WORKSPACE_NAME.xcworkspace" --scheme "$SCHEME" --skip_archive --configuration Debug --destination="platform=iOS Simulator,name=$simulatorName,OS=$RUNTIME" --skip_package_ipa true --buildlog_path gymbuildlog --xcargs "clean" --derived_data_path="$DERIVEDDATA"
    if [ $? -ne 0 ]; then
      cleanBuildDirectory
      exit -1
    fi

    #
    # Checking for warnings
    # 
    MAX_WARNINGS=0
    echo "[BUILD.SH] [`date +"%H:%M:%S"`] Checking for $MAX_WARNINGS warnings"
    WARNINGS=`egrep '^(/.+:[0-9+:[0-9]+:.(warning):|fatal|===)' "gymbuildlog/$PROJECT_NAME-$SCHEME.log" | uniq`
    NUM_WARNINGS=`echo $WARNINGS | egrep "(warning|fatal|===)" | wc -l`
    if [[ "$NUM_WARNINGS" -gt "$MAX_WARNINGS" ]]; then
      echo "There are $NUM_WARNINGS warnings, invalid build (max allowed warnings $MAX_WARNINGS"
      echo $WARNINGS
      cleanBuildDirectory
      exit -1
    fi

    echo "Nice,$NUM_WARNINGS warnings"

    # In case of only build, touch CICD result files so no error is thrown
    touch coverage/cobertura.xml
    touch fastlane/test_output/report.junit fastlane/test_output_ui/report.junit 

    cleanBuildDirectory
  fi

fi

unset DEVELOPER_DIR
EOF
)

echo "$BUILD_SH" > scripts/build.sh
sed -i "" -e "s/^export RUBY_VERSION=\"\"$/export RUBY_VERSION=\"$RUBY_VERSION\"/g" scripts/build.sh
sed -i "" -e "s/^export BUNDLER_VERSION=\"\"$/export BUNDLER_VERSION=\"$BUNDLER_VERSION\"/g" scripts/build.sh
sed -i "" -e "s/^WORKSPACE_NAME=\"\"$/WORKSPACE_NAME=\"$WORKSPACE_NAME\"/g" scripts/build.sh
sed -i "" -e "s/^PROJECT_NAME=\"\"$/PROJECT_NAME=\"$PROJECT_NAME\"/g" scripts/build.sh
sed -i "" -e "s/^SCHEME=\"\"$/SCHEME=\"$SCHEME\"/g" scripts/build.sh
sed -i "" -e "s/^TEST_TARGET=\"\"$/TEST_TARGET=\"$TEST_TARGET\"/g" scripts/build.sh
sed -i "" -e "s/^UI_TEST_TARGET=\"\"$/UI_TEST_TARGET=\"$UI_TEST_TARGET\"/g" scripts/build.sh
SAFE_PROJECT_NAME=`echo "$PROJECT_NAME" | tr -cd "[:alnum:]\n"`
sed -i "" -e "s/^export KEYCHAIN_NAME=\"\"$/export KEYCHAIN_NAME=\"$SAFE_PROJECT_NAME\"/g" scripts/build.sh

chmod +x scripts/build.sh

FASTFILE=$(cat <<"EOF"

import_from_git(url: 'http://gitlab.inqbarna.com/contrib/xcode-scripts.git',
               path: 'fastlane/CommonFastfile')

default_platform(:ios)

before_all do |lane, options|
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

  desc "Submit a new Test Build to Firebase"
  desc "This will also make sure the profile is up to date"
  lane :firebase do
    # This method from include does most of the job
    iq_firebase(schemename: "###",
                appname: "###",
                targetname: "###",
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

FOUND_SCRIPT=`grep "BUILD NUMBER FROM FASTLANE TO PLIST" "$PROJECT_NAME.xcodeproj/project.pbxproj"`
if [[ $FOUND_SCRIPT == "" ]]; then
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Switching to add_bundleversion_build_phase.rb"
  curl -fsSL http://gitlab.inqbarna.com/contrib/xcode-scripts/-/raw/master/samples/add_bundleversion_build_phase.rb > /tmp/add_bundleversion_build_phase.rb
  chmod +x /tmp/add_bundleversion_build_phase.rb
  bundle exec ruby /tmp/add_bundleversion_build_phase.rb
else
  echo "[CREATE_SETUP_BUILD_SCRIPTS.SH] Build phase that includes build number to apps plist already found in project"
fi
