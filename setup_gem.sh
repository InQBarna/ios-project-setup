#! /bin/bash


# Version methods
version_less_than_or_equal() {
    [  "$1" == `echo -e "$1\n$2" | sort -V | head -n1` ]
}
version_less_than() {
    [ "$1" == "$2" ] && return 1 || version_less_than_or_equal $1 $2
}

# Pre-checks
USER_BUNDLER_VERSION=`bundle --version | sed -e "s/.*\([0-9]\.[0-9]*\.[0-9]*\).*/\1/"`
BUNDLER_VERSION=$USER_BUNDLER_VERSION
echo $BUNDLER_VERSION
version_less_than "$USER_BUNDLER_VERSION" "2.2.21" && BUNDLER_VERSION="2.2.21"
echo "Will force bundle version $BUNDLER_VERSION"



# Writing Gemfile with cocoapods and fastlane
echo ""
echo "Creating Gemfile with cocoapods and fastlane"
echo ""
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



# Configure ruby (rbenv) GEMS
RUBY_VERSION="2.7.2"
MIN_GEM_VERSION="3.2.20"
echo ""
echo "Setting up/configuring ruby $RUBY_VERSION (rbenv), GEM >$MIN_GEM_VERSION and bundler $BUNDLER_VERSION"
echo ""
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
scripts/setup.sh

# pod install added later to setup script...
echo "
echo \"[SETUP.SH] Runnig pod install\"
bundle exec pod install || bundle exec pod install --repo-update || exit -1
" >> scripts/setup.sh


# build script
WORKSPACE_NAME=`find . -iname *.xcworkspace | head -n 1 | sed -e "s/\.\///g" | sed -e "s/\.xcworkspace//g"`
if [[ $WORKSPACE_NAME == "" ]]; then
  echo "[SETUP_GEM.SH] Could not find workspace file, build script won't be generated"
  exit -1
fi
PROJECT_NAME=`find . -iname *.xcodeproj | head -n 1 | sed -e "s/\.\///g" | sed -e "s/\.xcodeproj//g"`
if [[ $PROJECT_NAME == "" ]]; then
  echo "[SETUP_GEM.SH] Could not find workspace file, build script won't be generated"
  exit -1
fi
SCHEME_FILE=`find $WORKSPACE_NAME.xcworkspace/xcshareddata/xcschemes  -iname *.xcscheme | head -n 1`
SCHEME=`echo $SCHEME_FILE | sed -e "s/.*[/]\([^/]*\)\.xcscheme/\1/g"` 
echo "[SETUP_GEM.SH] Using scheme "$SCHEME" for build purposes (from $SCHEME_FILE)"
if [[ "$SCHEME_FILE" == "" || "$SCHEME" == "" ]]; then
  echo "[SETUP_GEM.SH] Error: There's no shared scheme on your workspace, for others to be able to build the same project you need a shared scheme in the workspace"
  echo "[SETUP_GEM.SH] You may have schemes set up on your project, please avoid this. Schemes should be added to workspace!!"
  echo "[SETUP_GEM.SH] Build script won't be generated"
  exit -1
fi
if [[ `git status $SCHEME_FILE | grep Untracked | wc -l` -gt 0 ]]; then
  echo "[SETUP_GEM.SH] Error: The file $SCHEME_FILE should be added to the version control system"
  echo "[SETUP_GEM.SH] Build script won't be generated"
  exit -1
fi
MAIN_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep -v "Tests" | grep -v "^$" | grep -v "Targets:" | sed -e "s/^[ ]*//g" | head -n 1`
if [[ "$MAIN_TARGET" == "" ]]; then
  echo "[SETUP_GEM.SH] Could not find main app target"
  echo "[SETUP_GEM.SH] Build script won't be generated"
  exit -1
fi
echo "[SETUP_GEM.SH] Using MAIN target "$MAIN_TARGET""
TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "[^U][^I]Tests" | sed -e "s/ *\([a-zA-Z ]*\)/\1/g" | head -n 1`
if [[ "$TEST_TARGET" == "" ]]; then
  TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "Tests" | sed -e "s/ *\([a-zA-Z ]*\)/\1/g" | head -n 1`
  if [[ "$TEST_TARGET" == "" ]]; then
    TEST_TARGET="${MAIN_TARGET}Tests"
    echo "[SETUP_GEM.SH] There's no test target in your project, will use ${TEST_TARGET} for testing purposes... but running tests won't work until you create it"
  fi
fi
UI_TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "UITests" | sed -e "s/^[ ]*//g" | head -n 1`
if [[ "$UI_TEST_TARGET" == "" ]]; then
  UI_TEST_TARGET="${MAIN_TARGET}UITests"
  echo "[SETUP_GEM.SH] There's no test target in your project, you can create a target named ${MAIN_TARGET}UITests later if you want to run ui test separately"
else
  echo "[SETUP_GEM.SH] Using test target "${UI_TEST_TARGET}" for UI test purposes"
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
  if [[ "$LOGIN_KEYCHAIN_PASSWORD" == "" ]]; then
    echo "[BUILD.SH] Missing LOGIN_KEYCHAIN_PASSWORD env variable, configure jenkins bindings or please use:"
    echo "[BUILD.SH] export LOGIN_KEYCHAIN_PASSWORD=XXX"
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
  [ ! -f ~/Library/Keychains/$KEYCHAIN_NAME-db ] &&  security create-keychain -p $LOGIN_KEYCHAIN_PASSWORD "$KEYCHAIN_NAME"
  security -v unlock-keychain -p "$LOGIN_KEYCHAIN_PASSWORD" ~/Library/Keychains/$KEYCHAIN_NAME-db
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
  if [ "$GITLAB_USER" != "" ] && [ "$GITLAB_PASSWORD" == "" ]; then
    ORIGIN=`git config -l | grep remote.origin.url | sed -e "s/remote.origin.url=//" | sed -e "s/:\/\/.*@/:\/\//g"`
    ORIGIN_WITH_CREDS=`echo $ORIGIN | sed -e "s/:\/\//:\/\/$GITLAB_USER:$GITLAB_PASSWORD@/g"`
  else
    ORIGIN_WITH_CREDS=`git config -l | grep remote.origin.url | sed -e "s/remote.origin.url=//" | sed -e "s/:\/\/.*@/:\/\//g"`
  fi

  #
  # Setup git creds for match and fastlane
  # 
  export MATCH_PASSWORD="$MATCH_PASSPHRASE"
  sed -i "" -e "s/http:\/\/gitlab.inqbarna.com/http:\/\/$GITLAB_USER:$GITLAB_PASSWORD@gitlab.inqbarna.com/" fastlane/Matchfile
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
    bundle exec fastlane match appstore --readonly --keychain_password $LOGIN_KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
    bundle exec fastlane match adhoc --readonly --keychain_password $LOGIN_KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"

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

    bundle exec fastlane match adhoc --readonly --keychain_password $LOGIN_KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
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

