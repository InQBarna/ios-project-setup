# How to set up a new project
1. Create the repository
2. Clone the repository
3. Create the xcode project on the root of the repository
4. Setup environment and bundler. We need an environment setup script so other users can create the same exact environment: ruby, gems, etc... using Bundler for example, we need to install fastlane and pods
    - `../xcode-scripts/setup_gem.sh` #This will just install bundler and gems
    - `bundle exec pod init`
    - `bundle exec pod install`
    - Open the project in xcode and create a shared target in the workspace
    - Add this shared target to version control system
    - `../xcode-scripts/setup_gem.sh`
5. Setup pods
    - Add Swiftlint to pods 
    - `pod 'SwiftLint'`
    - `pod 'Firebase/Crashlytics'`
    - (OPTIONAL) `pod 'SwiftFormat/CLI'` 
```
bundle exec pod init
bundle exec pod install
```
6. Setup fastlane
    - You need the apple account credentials and active
    - This is an interactive step
    - `bundle exec fastlane init`
    - Select automate beta distribution
    - Asked for login to appstore, developer team, appstore id
    - After fastlane setup you may edit Fastlane to look like:
```
import_from_git(url: 'http://gitlab.inqbarna.com/contrib/xcode-scripts.git',
               path: 'fastlane/CommonFastfile')

default_platform(:ios)

platform :ios do

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
                testers_cs: "###.###@inqbarna.com, ###.###@inqbarna.com")
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

```
7. Setup match
    - Please check the list of devices in the developer portal, having them cleaned right now would be nice!
    - Should work by just executing `../xcode-scripts/samples/setup_iqb_gitlab_match.sh`

8. Setup GITIGNORE
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
9. Common project setup
    - Add appstore config: `bundle exec ruby ../xcode-scripts/samples/add_appstore_config.rb`
    - Add swiftlint build phase `bundle exec ruby ../xcode-scripts/samples/add_swiftlint_build_phase.rb`
    - Add bundleversion auto-setting `bundle exec ruby ../xcode-scripts/samples/add_bundleversion_build_phase.rb`
    - (OPTIONAL) Add SwiftFormat build phase: `bundle exec ruby ../xcode-scripts/samples/add_swiftformat_build_phase.rb`

10. Firebase
    - Setup the project on firebase: Pods, addition of GoogleServices to project, appdelegate setup
    - Setup beta distribution on firebase
    - `fastlane add_plugin firebase_app_distribution`
    - setupfirebaseid correctly on Fastfile (see step 6)
    - `bundle exec fastlane update_devices_and_profiles` will create match prov profiles
    - Setup created match prov profiles manually on xcode project
    - `bundle exec fastlane firebase` should work ! (unless your project doesn't even compile :D )

TODO for setup_gem.sh:
    - Check for firebase pods
    - Check firebase plugin on fastlane
    - Check coverage is added to target
