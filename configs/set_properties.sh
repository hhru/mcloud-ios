#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )

# iSTF settings
export PROVIDER_NAME=iMac-Developer.local
export STF_PUBLIC_HOST=stage.qaprosoft.com
export STF_PRIVATE_HOST=192.168.88.95

export RETHINKDB_PORT_28015_TCP="tcp://${STF_PUBLIC_HOST}:28015"

export WEBSOCKET_PROTOCOL=ws
export WEB_PROTOCOL=http

# selenium hub settings
export hubHost=stage.qaprosoft.com
export hubPort=4446

export STF_PUBLIC_NODE_HOST=node-stage.qaprosoft.com
export STF_PRIVATE_NODE_HOST=192.168.88.96

export automation_name=XCUITest
export appium_home=/usr/local/lib/node_modules/appium

export devices=${BASEDIR}/devices.txt
export configFolder=${BASEDIR}/configs
export logFolder=${BASEDIR}/logs
export metaDataFolder=${BASEDIR}/metaData

#general vars declaration to parse devices.txt correctly
export name_position=1
export type_position=2
export os_version_position=3
export udid_position=4
export appium_port_position=5
export wda_port_position=6
export mjpeg_port_position=7
export iwdp_port_position=8

export stf_screen_port_position=9
export stf_appium_port_position=10

if [ ! -d "${BASEDIR}/logs" ]; then
    mkdir "${BASEDIR}/logs"
fi

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir "${BASEDIR}/metaData"
fi
