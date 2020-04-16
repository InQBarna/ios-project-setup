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

7. Setup GITIGNORE
```
curl "https://www.gitignore.io/api/xcode" >> .gitignore
echo ".bundle" >> .gitignore 
echo "bin" >> .gitignore 
echo "Pods" >> .gitignore 
```
8. Common project setup
    - Add appstore config: `../xcode-scripts/samples/add_appstore_config.rb`
    - Add swiftliny buld phase `../xcode-scripts/samples/add_swiftlint_build_phase.rb`
    - Add bundleversion auto-setting `../xcode-scripts/samples/add_bundleversion_build_phase.rb`
