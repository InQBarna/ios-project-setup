# Goals

We want to start a fresh project ready for CICD, which means

    - Easily build te project in any (CICD)  machine (with some minimum requirements). And guarantee 0 warnings!
    - Easily run the tests and guarante they pass. And report coverage!
    - Easily send a test version to stakeholders
    - Easily send a vertion to AppStoreConnect for a new release

## How to set up a new project

1. Grab the requirements:
    - Have the repository created on github/your platform
    - App name
    - Bundle identifier created on dev portal
    - Apple team id (from dev portal)
    - Match git repo url
    - Firebase app id (from firebase, looks like:  1:XXXX:ios:XXXX)
    - Auth p8 file (from dev portal)
      - Key id
      - Issuer id
      - Auth p8 file (from dev portal)
    - App created on appstoreconnect

2. Seriously... grab the requirements above or it will be harder to setup this later

3. Clone your project repository

4. Create the xcode project on the root of the repository.
    - Create an iOS project
    - Choose an existing bunddle id in dev portal
    - Close it before moving to step 3.

5. Run the scripts setup script by executing:
```
../xcode-scripts/create_setup_build_scripts.sh
```
    - Setup script should now be ready to be used, you can test it by executing: `./scripts/setup.sh`
    - Build script is created at: `./scripts/build.sh`. This is not ready to be used yet.
    - A build phase should now be added to the project to set the build number correctly with format: YYYYMMddHHmm.
    - If no fastlane folder is found, Fastfile and Appfile will have been generated at fastlane/FastFile fastlane/Appfile, please check they're created correctly
    -  MANUALLY: firebase id should be manually added to fastlane/Fastfile
    -  MANUALLY: the p8 file (key id and issuer id) should be manually downloaded and configured at fastlane/Fastfile
    -  MANUALLY: we recommend moving the scheme files to the workspace, and mark them as "shared", and deleting the file at \*.xcodeproj/project.xcworkspace
    -  MANUALLY: in the scheme -> test: please mark "gather coverage" for 'all targets'

At this point you should be able to run `./scripts/build.sh` correctly and it will build the project. It can also run the tests when setting the INTENT env variable like this: `export INTENT="test"`

6. Appstore
    - (OPTIONAL) MANUALLY write at least one device to `fastlane/devices.txt`, either MANUALLY or ... 
      - If you have correct credentials for it (doesn't work with keys, plain username/password), you can download the devices registered by running: `bundle exec fastlane update_devices_and_profiles`
    - Create the provisioning profiles using: `bundle exec fastlane update_devices_and_profiles`
      - MANUALLY unset "Automatically manage signing"
      - MANUALLY select the newly created prov profiles for every config

If you correctly commit all your work, now `bundle exec fastlane beta` should work ! (unless your project doesn't even compile :D )

7. (Optional) Firebase
    - `pod 'Firebase/Crashlytics'`
    - Setup the project on firebase, following the steps from console.firebase.com: Pods, addition of GoogleServices to project, appdelegate setup...
      - Right now adding firebase with SPM does not work correctly when uploading the debug symbols to crashlytics, please avoid SPM for firebase until solved
    - Enable beta distribution on firebase website
    - Setup beta distribution fastlane plugin on project running: `fastlane add_plugin firebase_app_distribution`
    - Check the correct firebaseid on Fastfile (if not done in step 5)
    - If you want to run the firebase distribution script locally, get sure you're logged in to firebase using `firebase login`

If you correctly commit all your work, now `bundle exec fastlane firebase` should work ! (unless your project doesn't even compile :D )

8. (Optional) Configure desired pods
    - Add Swiftlint to pods 
      - `pod 'SwiftLint'`
      - `pod 'SwiftFormat/CLI'` 
    - And run `./scripts/setup.sh` when done

9. (Optional) Other usual project setup
    - Add adhoc config to the project copying the Release config: `bundle exec ruby ../xcode-scripts/samples/add_adhoc_config.rb`
      - MANUALLY unset "Automatically manage signing"
      - MANUALLY select the correct prov profiles for adhoc config
      - MANUALLY change the configuration in Fastfile's iq_firebase_v2 to adhoc
    - Add swiftlint build phase `bundle exec ruby ../xcode-scripts/samples/add_swiftlint_build_phase.rb`
    - Or add SwiftFormat build phase: `bundle exec ruby ../xcode-scripts/samples/add_swiftformat_build_phase.rb`

TODO for setup_gem.sh:
    - Check current xcode version and target
    - Check for firebase pods
    - Check firebase plugin on fastlane
    - Check coverage is added to target
