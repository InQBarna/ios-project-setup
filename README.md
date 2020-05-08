# How to set up a new project
1. Create the repository
2. Clone the repository
3. Create the xcode project on the root of the repository
4. Setup environment and bundler. We need an environment setup script so other users can create the same exact environment: ruby, gems, etc... using Bundler for example, we need to install
    - fastlane
    - pods
   There's a script to do this at xcode-scripts (http://gitlab.inqbarna.com/contrib/xcode-scripts)
`../xcode-scripts/setup_gem.sh`
5. Setup pods
    - Add Swiftlint to pods 
    - `pod 'SwiftLint'`
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
7. Setup match
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
    - `fastlane add_plugin firebase_app_distribution`
    - add firebase lane TODO: sample or code
