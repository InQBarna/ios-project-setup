#! /bin/bash

# Writing Gemfile with cocoapods and fastlane
echo ""
echo "Creating Gemfile with cocoapods and fastlane"
echo ""
echo "source \"https://rubygems.org\"" > Gemfile
echo "" >> Gemfile
echo "gem 'fastlane'" >> Gemfile
echo "gem 'cocoapods'" >> Gemfile
echo "" >> Gemfile
echo "plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')" >> Gemfile
echo "eval_gemfile(plugins_path) if File.exist?(plugins_path)" >> Gemfile

# Configure ruby (rbenv) GEMS
echo ""
echo "Setting up/configuring ruby 2.6.5 (rbenv), GEM 3.0.3 and bundler 2.0.2"
echo ""
echo "which rbenv || brew install rbenv" > setup_ruby_gem_bundler_env.sh
echo "which gem | grep \".rbenv\" || eval \"\$(rbenv init -)\"" >> setup_ruby_gem_bundler_env.sh
echo "rbenv versions | grep 2\.6\.5 || rbenv install 2.6.5" >> setup_ruby_gem_bundler_env.sh
echo "rbenv local 2.6.5" >> setup_ruby_gem_bundler_env.sh
echo "ruby --version | grep \"2\.6\.5\" || exit -1" >> setup_ruby_gem_bundler_env.sh
echo "gem update --system 3.0.3 || exit -1" >> setup_ruby_gem_bundler_env.sh
echo "gem env | grep \"RUBY VERSION: 2\.6\.5\" || exit -1" >> setup_ruby_gem_bundler_env.sh
echo "gem install --user-install bundler:2.0.2" >> setup_ruby_gem_bundler_env.sh
echo "bundle --version | grep 2\.0\.2 || exit -1" >> setup_ruby_gem_bundler_env.sh
echo "bundle install --path=.bundle --binstubs=bin" >> setup_ruby_gem_bundler_env.sh
echo "bundle clean" >> setup_ruby_gem_bundler_env.sh
chmod +x ./setup_ruby_gem_bundler_env.sh
./setup_ruby_gem_bundler_env.sh

# Esooo
which xcproj || brew install xcproj

#export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer/"

#bundle exec pod install
#bundle exec fastlane install_profiles

#bundle exec fastlane action clear_derived_data
#bundle exec fastlane gym --workspace ./mSchools.xcworkspace --scheme mSchools --skip_archive --configuration Debug --destination='platform=iOS Simulator,name=iPhone X' --skip_package_ipa true --buildlog_path gymbuildlog --xcargs "clean analyze build-for-testing"

#unset DEVELOPER_DIR
