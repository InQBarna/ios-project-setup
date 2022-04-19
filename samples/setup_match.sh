#! /bin/bash

if [[ ! -f fastlane/Appfile ]]; then
    echo "Run fastlane first with 'automate app store distribution' or 'Manual setup'"
    exit -1
fi
TEAM_ID=`cat fastlane/Appfile | grep "^team_id" | sed -e 's/^team_id.*"\(.*\)".*$/\1/g'`
if [[ "$TEAM_ID" == "" ]]; then
    echo "Can't find needed team_id in fastlane/Appfile"
    exit -1
fi

APP_IDENTIFIER=`cat fastlane/Appfile | grep "^app_identifier" | sed -e 's/^app_identifier.*"\(.*\)".*$/\1/g'`
if [[ "$APP_IDENTIFIER" == "" ]]; then
    echo "Can't find needed app_identifier in fastlane/Appfile"
    exit -1
fi

# Writing Matchfile
echo "Creating Matchfile with team id $TEAM_ID"
echo "Pleas provide the url for the match repo"
read repo_url

echo "
git_url(\"$repo_url\")
storage_mode(\"git\")
git_branch \"$TEAM_ID\"

type(\"development\")
team_id \"$TEAM_ID\"
app_identifier [\"$APP_IDENTIFIER\"]
" > fastlane/Matchfile

# Writing Matchfile
if grep -v -q "import_from_git.*xcode-scripts" fastlane/Fastfile; then
  echo "Updating Fastfile to import default match lanes"
  sed -i '' -e "/default_platform(:ios)/i\ 
import_from_git(url: 'http:\/\/gitlab.inqbarna.com\/contrib\/xcode-scripts.git', path: 'fastlane\/CommonFastfile')" fastlane/Fastfile
fi

# echo "Building devices file"
# export FASTLANE_TEAM_ID=$TEAM_ID
# curl -fsSL http://gitlab.inqbarna.com/contrib/xcode-scripts/-/raw/master/samples/read_devices_from_developer_portal.rb > /tmp/read_devices_from_developer_portal.rb
# chmod +x /tmp/read_devices_from_developer_portal.rb
# bundle exec /tmp/read_devices_from_developer_portal.rb
echo "If you want to build the devices file from current device list please run samples/read_devices_from_developer_portal.rb"
