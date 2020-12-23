Zebrunner Device Farm (iOS slave)
==================

* It is built on the top of [OpenSTF](https://github.com/openstf) with supporting iOS devices remote control.

## Contents
* [Software prerequisites](#software-prerequisites)
* [iSTF components setup](#istf-components-setup)
* [iOS-slave setup](#ios-slave-setup)
* [Setup sync scripts via Launch Agents for Appium, WDA and STF services](#setup-sync-scripts-via-launch-agents-for-appium-wda-and-stf-services)
* [License](#license)

## Software prerequisites
* Install XCode 11.2
* Make sure you have latest Appium compatible node version installed (13.11.0+) or install it using [nvm](http://npm.github.io/installation-setup-docs/installing/using-a-node-version-manager.html).
* Install Appium 1.19.0+
* Install [nvm](https://github.com/nvm-sh/nvm) version manager
* Install v8.17.0 and latest node using nvm
  > 8.x node is still required by OpenSTF!


## iSTF components setup
* Install additional packages
```
brew install graphicsmagick zeromq protobuf yasm pkg-config
```
* Clone and build iSTF from sources
```
git clone --single-branch --branch master https://github.com/zebrunner/stf.git
cd stf
npm install
npm link
```

## iOS-slave setup
* Clone this repo
```
git clone --single-branch --branch master https://github.com/zebrunner/mcloud-ios.git
cd mcloud-ios
```
* Update devices.txt registering all whitelisted devices in it
```
# DEVICE NAME    | TYPE      | VERSION| UDID                                     |APPIUM|  WDA  | MJPEG | IWDP  | STF_SCREEN | PROXY_APPIUM
iPhone_7         | phone     | 12.3.1 | 48ert45492kjdfhgj896fea31c175f7ab97cbc19 | 4841 | 20001 | 20002 | 20003 |  7701      |  7702   
Phone_X1         | simulator | 12.3.1 | 7643aa9bd1638255f48ca6beac4285cae4f6454g | 4842 | 20011 | 20022 | 20023 |  7711      |  7712   
```
  > Put whitelisted simulators data into devices.txt too

* Run `./syncSimulators.sh` to authorize/whitelist simulators
  > sycnup simulators script should be executed manually on-demand when any simulator added/removed from the MacOS

* Update configs/set_properties.sh. Specify actual values for 
  * STF_MASTER_HOST
  * STF_NODE_HOST
  * WEBSOCKET_PROTOCOL
  * WEB_PROTOCOL
  * HUB_HOST
  * HUB_PORT

* Sign WebDriverAgent using your Dev Apple certificate and install WDA on each device manually
  * Open in XCode /usr/loca/lib/node_modules/appium/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj
  * Choose WebDriverAgentRunner and your device(s) 
  * Choose your dev certificate
  * Product -> Test. When WDA installed and started successfully Product -> Stop

* Verify that Appium/WDA and STF services can be launched successfully
```
cd mcloud-ios

./startWDA.sh <udid>
tail -f ./logs/<deviceName>_wda.log

./startAppium.sh <udid>
tail -f ./logs/<deviceName>_appium.log

./startSTF.sh <udid>
tail -f ./logs/<deviceName>_stf.log
```  

### Setup sync scripts via Launch Agents for Devices, Appium, WDA and STF services
  * Devices agent setup
  * WDA agent setup
  * Appium agent setup
  * STF agent setup
  
  > You can use [launchd](https://www.launchd.info/) to start/stop required services for connected/disconnected device(s). Details can be found in [README](https://github.com/zebrunner/mcloud-ios/blob/master/LaunchAgents/README.txt)

## License
Code - [Apache Software License v2.0](http://www.apache.org/licenses/LICENSE-2.0)

Documentation and Site - [Creative Commons Attribution 4.0 International License](http://creativecommons.org/licenses/by/4.0/deed.en_US)
