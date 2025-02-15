#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}


if [ -f backup/settings.env ]; then
  source backup/settings.env
fi

if [ -f .env ]; then
  source .env
fi

export devices=${BASEDIR}/devices.txt
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/logs/backup" ]; then
    mkdir -p "${BASEDIR}/logs/backup"
fi

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir "${BASEDIR}/metaData"
fi

# udid position in devices.txt to be able to read by sync scripts
export udid_position=4

export connectedDevices=${metaDataFolder}/connectedDevices.txt
export connectedSimulators=${metaDataFolder}/connectedSimulators.txt

  print_banner() {
  echo "
███████╗███████╗██████╗ ██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗      ██████╗███████╗
╚══███╔╝██╔════╝██╔══██╗██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝
  ███╔╝ █████╗  ██████╔╝██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝    ██║     █████╗
 ███╔╝  ██╔══╝  ██╔══██╗██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗    ██║     ██╔══╝
███████╗███████╗██████╔╝██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║    ╚██████╗███████╗
╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝     ╚═════╝╚══════╝
"

  }

  setup() {
    print_banner

    cp .env.original .env

    #TODO: add software prerequisites check like nvm, appium, xcode etc

    # load default interactive installer settings
    source backup/settings.env.original

    # load ./backup/settings.env if exist to declare ZBR* vars from previous run!
    if [[ -f backup/settings.env ]]; then
      source backup/settings.env
    fi

    export ZBR_MCLOUD_IOS_VERSION=1.0

    # Setup MCloud master host settings: protocol, hostname and port
    echo "MCloud SmartTestFarm Settings"
    local is_confirmed=0

    while [[ $is_confirmed -eq 0 ]]; do
      read -p "Master host protocol [$ZBR_MCLOUD_PROTOCOL]: " local_protocol
      if [[ ! -z $local_protocol ]]; then
        ZBR_MCLOUD_PROTOCOL=$local_protocol
      fi

      read -p "Master host address [$ZBR_MCLOUD_HOSTNAME]: " local_hostname
      if [[ ! -z $local_hostname ]]; then
        ZBR_MCLOUD_HOSTNAME=$local_hostname
      fi

      read -p "Master host port [$ZBR_MCLOUD_PORT]: " local_port
      if [[ ! -z $local_port ]]; then
        ZBR_MCLOUD_PORT=$local_port
      fi

      confirm "MCloud STF URL: $ZBR_MCLOUD_PROTOCOL://$ZBR_MCLOUD_HOSTNAME:$ZBR_MCLOUD_PORT/stf" "Continue?" "y"
      is_confirmed=$?
    done

    export ZBR_MCLOUD_PROTOCOL=$ZBR_MCLOUD_PROTOCOL
    export ZBR_MCLOUD_HOSTNAME=$ZBR_MCLOUD_HOSTNAME
    export ZBR_MCLOUD_PORT=$ZBR_MCLOUD_PORT

    local is_confirmed=0
    while [[ $is_confirmed -eq 0 ]]; do
      read -p "Current node host address [$ZBR_MCLOUD_NODE_HOSTNAME]: " local_hostname
      if [[ ! -z $local_hostname ]]; then
        ZBR_MCLOUD_NODE_HOSTNAME=$local_hostname
      fi
      confirm "Current node host address: $ZBR_MCLOUD_NODE_HOSTNAME" "Continue?" "y"
      is_confirmed=$?
    done
    export ZBR_MCLOUD_NODE_HOSTNAME=$ZBR_MCLOUD_NODE_HOSTNAME

    local is_confirmed=0
    while [[ $is_confirmed -eq 0 ]]; do
      read -p "Appium path [$ZBR_MCLOUD_APPIUM_PATH]: " local_value
      if [[ ! -z $local_value ]]; then
        ZBR_MCLOUD_APPIUM_PATH=$local_value
      fi
      confirm "Appium path: $ZBR_MCLOUD_APPIUM_PATH" "Continue?" "y"
      is_confirmed=$?
    done
    export ZBR_MCLOUD_APPIUM_PATH=$ZBR_MCLOUD_APPIUM_PATH

    replace .env "stf_master_host_value" "$ZBR_MCLOUD_HOSTNAME"
    replace .env "STF_MASTER_PORT=80" "STF_MASTER_PORT=$ZBR_MCLOUD_PORT"
    replace .env "node_host_value" "$ZBR_MCLOUD_NODE_HOSTNAME"
    replace .env "appium_path_value" "$ZBR_MCLOUD_APPIUM_PATH"

    if [ "$ZBR_MCLOUD_PROTOCOL" == "https" ]; then
      replace .env "WEBSOCKET_PROTOCOL=ws" "WEBSOCKET_PROTOCOL=wss"
      replace .env "WEB_PROTOCOL=http" "WEB_PROTOCOL=https"
    fi

    echo "Building iSTF component..."
    if [ ! -d stf ]; then
      git clone --single-branch --branch master https://github.com/zebrunner/stf.git
      cd stf
    else
      cd stf
      git pull
    fi
    nvm use v8
    npm install
    npm link --force
    cd "${BASEDIR}"

    # setup LaunchAgents
    cp LaunchAgents/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner.plist
    replace $HOME/Library/LaunchAgents/syncZebrunner.plist "working_dir_value" "${BASEDIR}"
    replace $HOME/Library/LaunchAgents/syncZebrunner.plist "user_value" "$USER"

    echo ""
    echo_warning "Make sure to register your devices and simulators in devices.txt!"

    syncSimulators
    # export all ZBR* variables to save user input
    export_settings

  }

  shutdown() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup MCloud iOS slave in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo_warning "Shutdown will erase all settings and data for \"${BASEDIR}\"!"
    confirm "" "      Do you want to continue?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner

    # unload LaunchAgents scripts
    launchctl unload $HOME/Library/LaunchAgents/syncZebrunner.plist

    # Stop existing services: WebDriverAgent, SmartTestFarm and Appium
    stop

    # remove configuration files and LaunchAgents plist(s)
    git checkout -- devices.txt

    rm -f $HOME/Library/LaunchAgents/syncZebrunner.plist

    rm -rf stf
  }

  start() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    print_banner

    #-------------- START EVERYTHING ------------------------------
    # load LaunchAgents script so all services will be started automatically
    launchctl load $HOME/Library/LaunchAgents/syncZebrunner.plist
  }

  start-services() {
    syncDevices
    syncWDA
    syncAppium
    syncSTF
  }

  start-appium() {
    udid=$1
    if [ "$udid" == "" ]; then
      syncAppium
      return 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    if [ "${session_ip}" == "" ]; then
      echo "Unable to start Appium for '${name}' as it's ip address not detected!" >> "logs/appium_${name}.log"
      exit -1
    fi
    echo "Starting appium: ${udid} - device name : ${name}"

    ./configs/configgen.sh $udid > ${BASEDIR}/metaData/$udid.json

    newWDA=false
    #TODO: investigate if tablet should be registered separately, what about tvOS

    nohup node ${APPIUM_HOME}/build/lib/main.js -p ${appium_port} --log-timestamp --device-name "${name}" --udid $udid \
      --tmp "${BASEDIR}/tmp/AppiumData/${udid}" \
      --default-capabilities \
     '{"mjpegServerPort": '${mjpeg_port}', "webkitDebugProxyPort": '${iwdp_port}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http://${session_ip}:${wda_port}'", "derivedDataPath":"'${BASEDIR}/tmp/DerivedData/${udid}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'$wda_port'", "usePrebuiltWDA": "true", "useNewWDA": "'$newWDA'", "platformVersion": "'$os_version'", "automationName":"'${AUTOMATION_NAME}'", "deviceName":"'$name'" }' \
      --nodeconfig ./metaData/$udid.json >> "logs/appium_${name}.log" 2>&1 &
  }

  start-stf() {
    udid=$1
    if [ "$udid" == "" ]; then
      syncSTF
      return 0
    fi
    #echo udid: $udid
    . configs/getDeviceArgs.sh $udid

    if [ "${session_ip}" == "" ]; then
      echo "Unable to start STF for '${name}' as it's ip address not detected!" >> "logs/stf_${name}.log"
      exit -1
    fi

    echo "Starting iSTF ios-device: ${udid} device name : ${name}"

    # Specify pretty old node v8.17.0 as current due to the STF dependency
    nvm use v8.17.0

    STF_BIN=`which stf`
    #echo STF_BIN: $STF_BIN

    STF_CLI=`echo "${STF_BIN//bin\/stf/lib/node_modules/@devicefarmer/stf/lib/cli}"`
    echo STF_CLI: $STF_CLI

    nohup node $STF_CLI ios-device --serial ${udid} \
      --device-name ${name} \
      --device-type ${type} \
      --provider ${STF_NODE_HOST} \
      --screen-port ${stf_screen_port} --connect-port ${mjpeg_port} --public-ip ${STF_MASTER_HOST} --group-timeout 3600 \
      --storage-url ${WEB_PROTOCOL}://${STF_MASTER_HOST}:${STF_MASTER_PORT}/ --screen-jpeg-quality 40 --screen-ping-interval 30000 \
      --screen-ws-url-pattern ${WEBSOCKET_PROTOCOL}://${STF_MASTER_HOST}/d/${STF_NODE_HOST}/${udid}/${stf_screen_port}/ \
      --boot-complete-timeout 60000 --mute-master never \
      --connect-app-dealer tcp://${STF_MASTER_HOST}:7160 --connect-dev-dealer tcp://${STF_MASTER_HOST}:7260 \
      --wda-host ${session_ip} --wda-port ${wda_port} \
      --appium-host ${STF_NODE_HOST} --appium-port ${appium_port} --proxy-appium-port ${proxy_appium_port} \
      --connect-sub tcp://${STF_MASTER_HOST}:7250 --connect-push tcp://${STF_MASTER_HOST}:7270 --no-cleanup >> "logs/stf_${name}.log" 2>&1 &

  }

  start-session() {
    # start WDA session correctly generating obligatory snapshot for default 'com.apple.springboard' application.
    udid=$1
    echo "Starting WDA session for $udid..."
    . ./configs/getDeviceArgs.sh $udid

    echo "ip: ${ip}; port: ${wda_port}"

    # start new WDA session with default 60 sec snapshot timeout
    sessionFile=${metaDataFolder}/tmp_${udid}.txt
    curl --silent --location --request POST "http://${ip}:${wda_port}/session" --header 'Content-Type: application/json' --data-raw '{"capabilities": {}}' > ${sessionFile}

    bundleId=`cat $sessionFile | grep "CFBundleIdentifier" | cut -d '"' -f 4`
    #echo bundleId: $bundleId

    sessionId=`cat $sessionFile | grep -m 1 "sessionId" | cut -d '"' -f 4`
    #echo sessionId: $sessionId

    if [[ "$bundleId" != "com.apple.springboard" ]]; then
      echo  "Activating springboard app forcibly..."
      curl --silent --location --request POST "http://${ip}:${wda_port}/session/$sessionId/wda/apps/launch" --header 'Content-Type: application/json' --data-raw '{"bundleId": "com.apple.springboard"}'
      sleep 1
      curl --silent --location --request POST "http://${ip}:${wda_port}/session" --header 'Content-Type: application/json' --data-raw '{"capabilities": {}}'
    fi
    rm -f ${sessionFile}

    cp ${metaDataFolder}/ip_${udid}.txt ${metaDataFolder}/session_${udid}.txt
  }

  start-wda() {
    udid=$1
    if [ "$udid" == "" ]; then
      syncWDA
      retun 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    #backup current wda log to be able to analyze failures if any
    if [[ -f logs/wda_${name}.log ]]; then
      mv logs/wda_${name}.log logs/backup/wda_${name}_`date +"%T"`.log
    fi

    echo Starting WDA: ${name}, udid: ${udid}, wda_port: ${wda_port}, mjpeg_port: ${mjpeg_port}
    nohup /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ${APPIUM_HOME}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj \
      -derivedDataPath "${BASEDIR}/tmp/DerivedData/${udid}" \
      -scheme WebDriverAgentRunner -destination id=$udid USE_PORT=$wda_port MJPEG_SERVER_PORT=$mjpeg_port test > "logs/wda_${name}.log" 2>&1 &

    verifyWDAStartup "logs/wda_${name}.log" 120 >> "logs/wda_${name}.log"
    if [[ $? = 0 ]]; then
      # WDA was started successfully!
      # parse ip address from log file line:
      # 2020-07-13 17:15:15.295128+0300 WebDriverAgentRunner-Runner[5660:22940482] ServerURLHere->http://192.168.88.127:20001<-ServerURLHere

      ip=`grep "ServerURLHere->" "logs/wda_${name}.log" | cut -d ':' -f 5`
      # remove forward slashes
      ip="${ip//\//}"
      # put IP address into the metadata file
      echo "${ip}" > ${metaDataFolder}/ip_${udid}.txt
    else
      # WDA is not started successfully!
      rm -f ${metaDataFolder}/ip_${udid}.txt
    fi
  }

  stop() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    stop-stf
    stop-appium
    stop-wda
  }

  stop-wda() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
      rm -f ${metaDataFolder}/ip_${udid}.txt
      rm -f ${metaDataFolder}/session_${udid}.txt
    else
      export pids=`ps -eaf | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
      rm -f ${metaDataFolder}/ip_*.txt
      rm -f ${metaDataFolder}/session_*.txt
    fi
    echo pids: $pids

    kill_processes $pids
  }

  stop-stf() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep 'ios-device' | grep 'stf' | grep -v grep | grep -v stop-stf | awk '{ print $2 }'`
    else
      export pids=`ps -eaf | grep 'ios-device' | grep 'stf' | grep -v grep | grep -v stop-stf | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }

  stop-appium() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
    else 
      export pids=`ps -eaf | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }


  restart() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    down
    start
  }

  down() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    # unload LaunchAgents scripts
    launchctl unload $HOME/Library/LaunchAgents/syncZebrunner.plist

    stop
  }

  backup() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

#    confirm "" "      Your services will be stopped. Do you want to do a backup now?" "n"
#    if [[ $? -eq 0 ]]; then
#      exit
#    fi

    print_banner

    cp devices.txt ./backup/devices.txt
    cp $HOME/Library/LaunchAgents/syncZebrunner.plist ./backup/syncZebrunner.plist

    echo "Backup for Device Farm iOS slave was successfully finished."

#    echo_warning "Your services needs to be started after backup."
#    confirm "" "      Start now?" "y"
#    if [[ $? -eq 1 ]]; then
#      start
#    fi

  }

  restore() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    confirm "" "      Your services will be stopped and current data might be lost. Do you want to do a restore now?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner
    down
    cp ./backup/devices.txt devices.txt
    cp ./backup/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner.plist

    echo_warning "Your services needs to be started after restore."
    confirm "" "      Start now?" "y"
    if [[ $? -eq 1 ]]; then
      start
    fi

  }

  version() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    source backup/settings.env

    echo "MCloud Device Farm: ${ZBR_MCLOUD_IOS_VERSION}"
  }

  export_settings() {
    export -p | grep "ZBR" > backup/settings.env
  }

  confirm() {
    local message=$1
    local question=$2
    local isEnabled=$3

    if [[ "$isEnabled" == "1" ]]; then
      isEnabled="y"
    fi
    if [[ "$isEnabled" == "0" ]]; then
      isEnabled="n"
    fi

    while true; do
      if [[ ! -z $message ]]; then
        echo "$message"
      fi

      read -p "$question y/n [$isEnabled]:" response
      if [[ -z $response ]]; then
        if [[ "$isEnabled" == "y" ]]; then
          return 1
        fi
        if [[ "$isEnabled" == "n" ]]; then
          return 0
        fi
      fi

      if [[ "$response" == "y" || "$response" == "Y" ]]; then
        return 1
      fi

      if [[ "$response" == "n" ||  "$response" == "N" ]]; then
        return 0
      fi

      echo "Please answer y (yes) or n (no)."
      echo
    done
  }

  kill_processes()
  {
    processes_pids=$*
    if [ "${processes_pids}" != "" ]; then
     echo processes_pids to kill: $processes_pids
     kill -9 $processes_pids
    fi
  }

  verifyWDAStartup() {

    ## FUNCTION:     verifyStartup
    ## DESCRITION:   verify if WDA component started per device/simolator
    ## PARAMETERS:
    ##         $1 - Path to log file for startup verification
    ##         $2 - String to find in startup log (startup indicator)
    ##         $3 - Counter. (Startup verification max duration) = (Counter) x (10 seconds)

    STARTUP_LOG=$1
    STARTUP_COUNTER=$2

    STARTUP_INDICATOR="ServerURLHere->"
    FAIL_INDICATOR=" TEST FAILED "
    UNSUPPORTED_INDICATOR="Unable to find a destination matching the provided destination specifier"

    COUNTER=0
    while [  $COUNTER -lt $STARTUP_COUNTER ];
    do
      sleep 1
      if [[ -r ${STARTUP_LOG} ]]
      then
        # verify that WDA is supported for device/simulator
        grep "${UNSUPPORTED_INDICATOR}" ${STARTUP_LOG} > /dev/null
        if [[ $? = 0 ]]
        then
          echo "ERROR! WDA does not support ${name}!"
          return -1
        fi

        # verify that WDA failed
        grep "${FAIL_INDICATOR}" ${STARTUP_LOG} > /dev/null
        if [[ $? = 0 ]]
        then
          echo "ERROR! WDA failed on ${name} in ${COUNTER} seconds!"
          return -1
        fi

       grep "${STARTUP_INDICATOR}" ${STARTUP_LOG} > /dev/null
        if [[ $? = 0 ]]
        then
          echo "WDA started successfully on ${name} within ${COUNTER} seconds."
          return 0
        else
          echo "WDA not started yet on ${name}. waiting ${COUNTER} sec..."
        fi

      else
        echo "ERROR! Cannot read from ${STARTUP_LOG}. File has not appeared yet!"
      fi
      let COUNTER=COUNTER+1
    done

    echo "ERROR! WDA not started on ${name} within ${STARTUP_COUNTER} seconds!"
    return -1
  }

  echo_warning() {
    echo "
      WARNING! $1"
  }

  echo_telegram() {
    echo "
      For more help join telegram channel: https://t.me/zebrunner
      "
  }

  echo_help() {
    echo "
      Usage: ./zebrunner.sh [option]
      Flags:
          --help | -h    Print help
      Arguments:
          setup               Setup Device Farm iOS slave
          start               Start Device Farm iOS slave services
          start-appium [udid] Start Appium services [all or for exact device by udid]
          start-stf [udid]    Start STF services [all or for exact device by udid]
          start-wda [udid]    Start WDA services [all or for exact device by udid]
          stop                Stop Device Farm iOS slave services
          stop-appium [udid]  Stop Appium services [all or for exact device by udid]
          stop-stf [udid]     Stop STF services [all or for exact device by udid]
          stop-wda [udid]     Stop WebDriverAgent services [all or for exact device by udid]
          restart             Restart Device Farm iOS slave services
          down                Stop Device Farm iOS slave services and disable LaunchAgent services
          shutdown            Destroy Device Farm iOS slave completely
          backup              Backup Device Farm iOS slave services
          restore             Restore Device Farm iOS slave services
          version             Version of Device Farm iOS slave"
      echo_telegram
      exit 0
  }

  syncDevices() {
    echo `date +"%T"` Sync Devices script started
    devicesFile=${metaDataFolder}/connectedDevices.txt
    /usr/local/bin/ios-deploy -c -t 3 > ${connectedDevices}
  }

  syncSimulators() {
    echo `date +"%T"` Sync Simulators script started
    simulatorsFile=${metaDataFolder}/connectedSimulators.txt
    # xcrun xctrace list devices - this command can not be used because it returns physical devices as well
    xcrun simctl list | grep -v "Unavailable" | grep -v "unavailable" > ${simulatorsFile}
  }

  syncWDA() {
    echo `date +"%T"` Sync WDA script started
    # use-case when on-demand manual "./zebrunner.sh start-wda" is running!
    isRunning=`ps -ef | grep start-wda | grep -v grep`
    #echo isRunning: $isRunning

    if [[ -n "$isRunning" ]]; then
      echo WebDriverAgent is being starting already. Skip sync operation!
      return 0
    fi

    # verify one by one connected devices and authorized simulators
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [ "$udid" = "UDID" ]; then
        continue
      fi
      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      #wda check is only for approach with syncWda.sh and usePrebuildWda=true
      wda=`ps -ef | grep xcodebuild | grep $udid | grep WebDriverAgent`

      physical=`cat ${connectedDevices} | grep $udid`
      simulator=`cat ${connectedSimulators} | grep $udid`
      device="$physical$simulator"
      #echo device: $device

      if [[ -n "$device" &&  -z "$wda" ]]; then
        # simultaneous WDA launch is not supported by Xcode!
        # error: error: accessing build database "/Users/../Library/Developer/Xcode/DerivedData/WebDriverAgent-../XCBuildData/build.db": database is locked
        # Possibly there are two concurrent builds running in the same filesystem location.
        ${BASEDIR}/zebrunner.sh start-wda $udid
        ${BASEDIR}/zebrunner.sh start-session $udid &
      elif [[ -z "$device" &&  -n "$wda" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device}" ]]; then
          echo "WDA will be stopped: ${udid} - device name : ${name}"
          ${BASEDIR}/zebrunner.sh stop-wda $udid &
        fi
      fi
    done < ${devices}
  }

  syncAppium() {
    echo `date +"%T"` Sync Appium script started

    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi
      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      appium=`ps -ef | grep ${APPIUM_HOME}/build/lib/main.js  | grep $udid`

      physical=`cat ${connectedDevices} | grep $udid`
      simulator=`cat ${connectedSimulators} | grep $udid`
      device="$physical$simulator"
      #echo device: $device

      wda=${metaDataFolder}/ip_${udid}.txt
      #echo wda: $wda

      if [[ -n "$appium" && ! -f "$wda" ]]; then
        echo "Stopping Appium process as no WebDriverAgent process detected. ${udid} device name : ${name}"
        ${BASEDIR}/zebrunner.sh stop-appium $udid &
        continue
      fi

      if [[ -n "$device" && -f "$wda" && -z "$appium" ]]; then
        ${BASEDIR}/zebrunner.sh start-appium $udid &
      elif [[ -z "$device" &&  -n "$appium" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device}" ]]; then
          echo "Appium will be stopped: ${udid} - device name : ${name}"
          ${BASEDIR}/zebrunner.sh stop-appium $udid &
        fi
      fi
    done < ${devices}
  }

  syncSTF() {
    echo `date +"%T"` Sync STF script started

    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [ "$udid" = "UDID" ]; then
        continue
      fi
      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      physical=`cat ${connectedDevices} | grep $udid`
      simulator=`cat ${connectedSimulators} | grep $udid`

      if [[ -n "$simulator" ]]; then
        # https://github.com/zebrunner/stf/issues/168
        # simulators temporary unavailable in iSTF
        continue
      fi

      device="$physical$simulator"
      #echo device: $device

      stf=`ps -eaf | grep ${udid} | grep 'ios-device' | grep -v grep`
      wda=${metaDataFolder}/ip_${udid}.txt
      if [[ -n "$stf" && ! -f "$wda" ]]; then
        echo "Stopping STF process as no WebDriverAgent process detected. ${udid} device name : ${name}"
        ${BASEDIR}/zebrunner.sh stop-stf $udid &
        continue
      fi

      if [[ -n "$device" && -f "$wda" && -z "$stf" ]]; then
        ${BASEDIR}/zebrunner.sh start-stf $udid &
      elif [[ -z "$device" && -n "$stf" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device_status=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device_status}" ]]; then
          echo "The iSTF ios-device will be stopped: ${udid} device name : ${name}"
          ${BASEDIR}/zebrunner.sh stop-stf $udid &
        fi
      fi
    done < ${devices}
  }

  replace() {
    #TODO: https://github.com/zebrunner/zebrunner/issues/328 organize debug logging for setup/replace
    file=$1
    #echo "file: $file"
    content=$(<$file) # read the file's content into
    #echo "content: $content"

    old=$2
    #echo "old: $old"

    new=$3
    #echo "new: $new"
    content=${content//"$old"/$new}

    #echo "content: $content"

    printf '%s' "$content" >$file    # write new content to disk
  }

if [ ! -d "$HOME/.nvm" ]; then
  echo_warning "NVM must be installed as prerequisites!"
  exit -1
fi

#load NVM into the bash path
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

case "$1" in
    setup)
        setup
        ;;
    start)
        start
        ;;
    start-appium)
        start-appium $2
        ;;
    start-stf)
        start-stf $2
        ;;
    start-wda)
        start-wda $2
        ;;
    start-session)
        start-session $2
        ;;
    start-services)
        start-services
        ;;
    stop)
        stop
        ;;
    stop-appium)
        stop-appium $2
        ;;
    stop-stf)
        stop-stf $2
        ;;
    stop-wda)
        stop-wda $2
        ;;
    restart)
        restart
        ;;
    down)
        down
        ;;
    shutdown)
        shutdown
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    authorize-simulator)
        syncSimulators
        ;;
    version)
        version
        ;;
    *)
        echo "Invalid option detected: $1"
        echo_help
        exit 1
        ;;
esac

