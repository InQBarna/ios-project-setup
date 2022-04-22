#!/bin/sh

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export RUBY_VERSION="2.7.2"
export PATH=/usr/local/bin/:$PATH

if [ "$#" -ne 1 ]
then
  echo "Usage: install.sh {XCODE_VERSION}"
  echo "Example: install.sh 13.2.1"
  exit 1
fi

echo "[INSTALL.SH] Configuring ruby and checking bundler version"
which gem | grep ".rbenv" || eval "$(rbenv init -)"
bundle --version | grep "$BUNDLER_VERSION" || exit -1

echo "[INSTALL.SH] Checking input parameters"
if [[ "$XCODE_INSTALL_USER" == "" ]]; then
    echo "[INSTALL.SH] Missing XCODE_INSTALL_USER env variable, configure with a valid developer account"
    echo "[INSTALL.SH] export XCODE_INSTALL_USER=XXX"
    exit -1
fi
if [[ "$XCODE_INSTALL_PASSWORD" == "" ]]; then
    echo "[INSTALL.SH] Missing XCODE_INSTALL_PASSWORD env variable, configure with a valid developer account"
    echo "[INSTALL.SH] export XCODE_INSTALL_PASSWORD=XXX"
    exit -1
fi

bundle install

VERSION=$1
bundle exec xcversion cleanup
bundle exec xcversion install $VERSION
bundle exec xcversion select $VERSION --symlink
bundle exec xcversion install-cli-tools
#codesign -f -s XcodeSigner /Applications/Xcode-$VERSION.app
bundle exec xcversion cleanup
