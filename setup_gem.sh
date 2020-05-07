#! /bin/bash

# Writing Gemfile with cocoapods and fastlane
echo ""
echo "Creating Gemfile with cocoapods and fastlane"
echo ""
echo "source \"https://rubygems.org\"

gem 'fastlane'
gem 'cocoapods'
gem 'xcodeproj'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
" > Gemfile

# Configure ruby (rbenv) GEMS
RUBY_VERSION="2.6.5"
GEM_VERSION="3.0.3"
BUNDLER_VERSION="2.0.2"
echo ""
echo "Setting up/configuring ruby $RUBY_VERSION (rbenv), GEM $GEM_VERSION and bundler $BUNDLER_VERSION"
echo ""
if [[ ! -d scripts ]]; then
    mkdir scripts
fi
echo "#!/bin/sh
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# GEMS
export RUBY_VERSION=\"$RUBY_VERSION\"
export BUNDLER_VERSION=\"$BUNDLER_VERSION\"
export GEM_VERSION=\"$GEM_VERSION\"
export PATH=/usr/local/bin/:\$PATH
which rbenv || brew install rbenv
which gem | grep \".rbenv\" || eval \"\$(rbenv init -)\"
rbenv versions | grep \"\$RUBY_VERSION\" || rbenv install \$RUBY_VERSION
rbenv local \$RUBY_VERSION
ruby --version | grep \"\$RUBY_VERSION\" || exit -1
gem env | grep \"RUBY VERSION: \$RUBY_VERSION\" || exit -1
gem install --user-install bundler:\$BUNDLER_VERSION
bundle --version | grep \"\$BUNDLER_VERSION\" || exit -1
bundle install
#bundle clean

" > scripts/setup.sh
chmod +x scripts/setup.sh
scripts/setup.sh

# pod install added later to setup script...
echo "bundle exec pod install || bundle exec pod install --repo-update || exit -1
" >> scripts/setup.sh
