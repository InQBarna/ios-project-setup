# How to set up a new project
1. Create and clone the repository, grab the requirements:
  - App name, bundle identifier...
  - Apple team id
  - Match repo url
  - firebase upload key
  - p8 file to upload to the store
2. Create the xcode project on the root of the repository. Close it before moving to step 3.
3. Run the scripts setup script by executing:
```
../xcode-scripts/create_setup_build_scripts.sh
```
 - Setup script should now be ready to be used, you can test it by executing: `./scripts/setup.sh`
 - Build script should now be ready to be used, you can test it by executing: `./scripts/build.sh`
 - A build phase should now be added to the project to set the build number correctly with format: YYYYMMddHHmm, otherwise you can run `bundle exec ruby ../xcode-scripts/samples/add_bundleversion_build_phase.rb`
 - If no fastfiles are found, Fastfile and Appfile will have been generated at fastlane/FastFile fastlane/Appfile, please check correct parameters
 -  firebase id should be manually added to fastlane/Fastfile
 -  the p8 file should be manually downloaded and configured at fastlane/Fastfile
4. Configure desired pods
    - Add Swiftlint to pods 
    - `pod 'Firebase/Crashlytics'`
    - (OPTIONAL) `pod 'SwiftLint'`
    - (OPTIONAL) `pod 'SwiftFormat/CLI'` 
    - And run `./scripts/setup.sh` when done
5. Setup GITIGNORE
```
curl "https://www.gitignore.io/api/xcode" >> .gitignore
echo "Pods" >> .gitignore 
echo "fastlane/README.md" >> .gitignore 
echo "fastlane/report.xml" >> .gitignore 
echo "## Obj-C/Swift specific" >> .gitignore
echo "*.hmap" >> .gitignore
echo "*.ipa" >> .gitignore
echo "*.dSYM.zip" >> .gitignore
echo "*.dSYM" >> .gitignore
echo ".DS_Store" >> .gitignore
```
6. Other usual project setup (OPTIONAL)
    - Add adhoc config to the project copying the Release config: `bundle exec ruby ../xcode-scripts/samples/add_adhoc_config.rb`
    - Add swiftlint build phase `bundle exec ruby ../xcode-scripts/samples/add_swiftlint_build_phase.rb`
    - Or add SwiftFormat build phase: `bundle exec ruby ../xcode-scripts/samples/add_swiftformat_build_phase.rb`

7. Firebase
    - Setup the project on firebase: Pods, addition of GoogleServices to project, appdelegate setup
    - Setup beta distribution on firebase
    - `fastlane add_plugin firebase_app_distribution`
    - setupfirebaseid correctly on Fastfile (see step 6)
    - `bundle exec fastlane update_devices_and_profiles` will create match prov profiles
    - Setup created match prov profiles manually on xcode project
    - `bundle exec fastlane firebase` should work ! (unless your project doesn't even compile :D )

8. Appstore
    - If you want to download the list of devices from the dev portal and have correct credentials for it, just run: `bundle exec fastlane update_devices_and_profiles`

TODO for setup_gem.sh:
    - Check current xcode version and target
    - Check for firebase pods
    - Check firebase plugin on fastlane
    - Check coverage is added to target
