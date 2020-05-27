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
version_less_than "$USER_BUNDLER_VERSION" "2.0.2" && BUNDLER_VERSION="2.0.2"
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
RUBY_VERSION="2.6.5"
MIN_GEM_VERSION="3.0.3"
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
SCHEME=`echo $SCHEME_FILE | sed -e "s/.*[/]\([a-zA-Z0-9 ]*\)\.xcscheme/\1/g"` 
echo "[SETUP_GEM.SH] Using scheme "$SCHEME" for build purposes"
if [[ "$SCHEME_FILE" == "" || "$SCHEME" == "" ]]; then
  echo "[SETUP_GEM.SH] There's no shared scheme on your workspace, for others to be able to build the same project you need a shared scheme in the workspace"
  echo "[SETUP_GEM.SH] You may have schemes set up on your project, please avoid this. Schemes should be added to workspace!!"
  echo "[SETUP_GEM.SH] Build script won't be generated"
  exit -1
fi
if [[ `git status $SCHEME_FILE | grep Untracked | wc -l` -gt 0 ]]; then
  echo "[SETUP_GEM.SH] The file $SCHEME_FILE should be added to the version control system"
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
TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "[^U][^I]Tests$" | sed -e "s/ *\([a-zA-Z ]*\)Tests/\1/g" | sed -e "s/^[ ]*//g" | head -n 1`
echo "[SETUP_GEM.SH] Using test target "${TEST_TARGET}Tests" for test purposes"
if [[ "$TEST_TARGET" == "" ]]; then
  TEST_TARGET="${MAIN_TARGET}Tests"
  echo "[SETUP_GEM.SH] There's no test target in your project, will use ${MAIN_TARGET}Tests for testing purposes... but running tests won't work until you create it"
else
  TEST_TARGET="${TEST_TARGET}Tests"
fi
UI_TEST_TARGET=`xcodebuild -project $PROJECT_NAME.xcodeproj -list 2>/dev/null | sed -n '/Targets/,/^$/p' | grep "UITests$" | sed -e "s/ *\([a-zA-Z ]*\)UITests/\1/g" | sed -e "s/^[ ]*//g" | head -n 1`
echo "[SETUP_GEM.SH] Using ui test target "${UI_TEST_TARGET}UITests" for test purposes"
if [[ "$UI_TEST_TARGET" == "" ]]; then
  UI_TEST_TARGET="${MAIN_TARGET}UITests"
  echo "[SETUP_GEM.SH] There's no test target in your project, will use ${MAIN_TARGET}UITests for testing purposes... but running tests won't work until you create it"
else
  UI_TEST_TARGET="${UI_TEST_TARGET}UITests"
fi

BUILD_SH=$(cat <<"EOF"
#!/bin/sh

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export RUBY_VERSION=""
export BUNDLER_VERSION=""
export PATH=/usr/local/bin/:$PATH
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer/"
export RUNTIME="13.3"
export DEVICE="iPhone 8"

echo "[BUILD.SH] Configuring ruby and checking bundler version"
which gem | grep ".rbenv" || eval "$(rbenv init -)"
bundle --version | grep "$BUNDLER_VERSION" || exit -1

echo "[BUILD.SH] Checking input parameters"
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
if [[ "$GITLAB_PASSWORD" == "" ]]; then
    echo "[BUILD.SH] Missing GITLAB_PASSWORD env variable, configure jenkins bindings or please use:"
    echo "[BUILD.SH] export GITLAB_PASSWORD=XXX"
    exit -1
fi

echo "[BUILD.SH] Checking available runtime $RUNTIME and correct simulator $DEVICE"
FOUND_DEVICE=`xcrun simctl list | sed -n "/-- iOS $RUNTIME --/,/-- /p" | grep "$DEVICE (" | sed -e "s/    $DEVICE [(]\([^)]*\).*/\1/"`
if [[ "$FOUND_DEVICE" == "" ]]; then 
    RUNTIME_TYPE=`xcrun simctl list | sed -n '/== Runtimes ==/,/== /p' | grep "iOS $RUNTIME (" | sed -e "s/.*) - \(.*\)/\1/"`
    if [[ "$RUNTIME_TYPE" == "" ]]; then
        echo "[BUILD.SH] Could not found installed runtime $RUNTIME. Aborting"
        echo "[BUILD.SH] run \"xcrun simctl list\" and double check $RUNTIME is NOT available"
        exit -1
    fi
    DEVICE_TYPE=`xcrun simctl list | sed -n '/== Device Types ==/,/== /p' | grep "$DEVICE (" | sed -e "s/$DEVICE [(]\([^)]*\).*/\1/"`
    if [[ "$DEVICE_TYPE" == "" ]]; then
        echo "[BUILD.SH] Could not found device type $DEVICE. Aborting"
        echo "[BUILD.SH] run \"xcrun simctl list\" and double check $DEVICE is NOT available"
        exit -1
    fi
    echo "[BUILD.SH] Creating device $DEVICE ($DEVICE_TYPE) with runtime $RUNTIME ($RUNTIME_TYPE)"
    #xcrun simctl create "$DEVICE" "com.apple.CoreSimulator.SimDeviceType.iPhone-8" "com.apple.CoreSimulator.SimRuntime.iOS-13-3"
    xcrun simctl create "$DEVICE" "$DEVICE_TYPE" "$RUNTIME_TYPE"
fi

echo "[BUILD.SH] Reset $DEVICE state and removing previous data"
xcrun simctl shutdown $FOUND_DEVICE
xcrun simctl erase $FOUND_DEVICE

# Set up keychain and fill it with match
echo "[BUILD.SH] Setting up keychain with match profiles"
export MATCH_PASSWORD="$MATCH_PASSPHRASE"
export KEYCHAIN_NAME=""
[ ! -f ~/Library/Keychains/$KEYCHAIN_NAME-db ] &&  security create-keychain -p $LOGIN_KEYCHAIN_PASSWORD "$KEYCHAIN_NAME"
security -v unlock-keychain -p "$LOGIN_KEYCHAIN_PASSWORD" ~/Library/Keychains/$KEYCHAIN_NAME-db
sed -i "" -e "s/http:\/\/gitlab.inqbarna.com/http:\/\/cicd:$GITLAB_PASSWORD@gitlab.inqbarna.com/" fastlane/Matchfile
bundle exec fastlane match development --readonly --keychain_password $LOGIN_KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
if [[ $INTENT == "firebase" ]]; then
    bundle exec fastlane match adhoc --readonly --keychain_password $LOGIN_KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
elif [[ $INTENT == "beta" ]]; then
    bundle exec fastlane match appstore --readonly --keychain_password $LOGIN_KEYCHAIN_PASSWORD --keychain_name "$KEYCHAIN_NAME"
fi
sed -i "" -e "s/http:\/\/cicd:$GITLAB_PASSWORD@gitlab.inqbarna.com/http:\/\/gitlab.inqbarna.com/" fastlane/Matchfile

echo "[BUILD.SH] Using keychain \"$KEYCHAIN_NAME\", and unlocking it for build"
if [[ `cat fastlane/Gymfile | grep OTHER_XCODE_SIGN_FLAGS | wc -l` == 1 ]]; then
    echo "[BUILD.SH] Gymfile with OTHER_XCODE_SIGN_FLAGS not supported by this script, please report the issue if necessary"
    exit -1
fi
echo "xcargs \"OTHER_CODE_SIGN_FLAGS=--keychain=\\\"~/Library/Keychains/$KEYCHAIN_NAME-db\\\"\"" > fastlane/Gymfile
security list-keychains -d user -s ~/Library/Keychains/$KEYCHAIN_NAME-db
security set-keychain-settings ~/Library/Keychains/$KEYCHAIN_NAME-db

echo "[BUILD.SH] Cleaning derived data"
bundle exec fastlane action clear_derived_data

WORKSPACE_NAME=""
PROJECT_NAME=""
SCHEME=""
TEST_TARGET=""
UI_TEST_TARGET=""
if [[ $INTENT == "test" ]]; then

    echo "[BUILD.SH] Building app for testing"
    bundle exec fastlane gym --workspace "./$WORKSPACE_NAME.xcworkspace" --scheme "$SCHEME" --skip_archive --configuration Debug --destination="platform=iOS Simulator,name=$DEVICE" --skip_package_ipa true --buildlog_path gymbuildlog --xcargs "clean analyze build-for-testing"

    echo "[BUILD.SH] Running unit tests"
    bundle exec fastlane scan --test_without_building="true" --devices="$DEVICE ($RUNTIME)" --code_coverage="true" --clean="false" --only_testing="$TEST_TARGET"
    bundle exec slather coverage --cobertura-xml --output-directory coverage --ignore "Pods/*" --ignore "*Tests/*" --scheme "$SCHEME" --workspace "$WORKSPACE_NAME.xcworkspace" "$PROJECT_NAME.xcodeproj"

    echo "[BUILD.SH] Running UI tests"
    rm -Rf "fastlane/test_output_ui/$PROJECT_NAME.xcresult"
    bundle exec fastlane scan --test_without_building="true" --devices="$DEVICE ($RUNTIME)" --code_coverage="false" --clean="false" --only_testing="$UI_TEST_TARGET" --output_directory="fastlane/test_output_ui" --result_bundle="true" || true
    xchtmlreport -r "./fastlane/test_output_ui/$PROJECT_NAME.xcresult"

    # These lines below are for parallel testing 
    #bundle exec fastlane scan --test_without_building="true" --devices="$DEVICE ($RUNTIME)" --code_coverage="false" --clean="false" --only_testing="$UI_TEST_TARGET" --xcargs="-resultBundlePath \"fastlane/test_output_ui/$PROJECT_NAME.xcresult\" -parallel-testing-enabled YES -parallel-testing-worker-count 2" || true
    #find "fastlane/test_output_ui/$PROJECT_NAME.xcresult" -iname StandardOutputAndStandardError.txt -exec cat {} \; | ./bin/xcpretty -r junit -o fastlane/test_output_ui/report.junit
    #xchtmlreport -r "./fastlane/test_output_ui/$PROJECT_NAME.xcresult"

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
    bundle exec fastlane firebase

elif [[ $INTENT == "beta" ]]; then

    echo "[BUILD.SH] Uploading to appstore using fastlane"
    bundle exec fastlane beta

else

    echo "[BUILD.SH] Building app for testing"
    bundle exec fastlane gym --workspace "./$WORKSPACE_NAME.xcworkspace" --scheme "$SCHEME" --skip_archive --configuration Debug --destination="platform=iOS Simulator,name=$DEVICE" --skip_package_ipa true --buildlog_path gymbuildlog --xcargs "clean analyze build"
    touch coverage/cobertura.xml
    touch fastlane/test_output/report.junit fastlane/test_output_ui/report.junit 
fi

echo "[BUILD.SH] Cleanup"
security list-keychains -d user -s ~/Library/Keychains/login.keychain-db
sed -i "" -e "/OTHER_CODE_SIGN_FLAGS.*/d" fastlane/Gymfile
if [[ `cat fastlane/Gymfile` == "" ]];
     # Removing Gymfile since we created it!
     then rm fastlane/Gymfile
fi
#rm -Rf gymbuildlog # do not delete, used for static analysis
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

