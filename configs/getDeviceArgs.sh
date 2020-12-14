#!/bin/bash

devicePattern=$1

if [ "$devicePattern" == "" ]; then
	exit -1
fi

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
. ${BASEDIR}/configs/set_properties.sh

name=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${name_position}`
export name=$(echo $name)

type=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${type_position}`
export type=$(echo $type)

os_version=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${os_version_position}`
export os_version=$(echo $os_version)

udid=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${udid_position}`
export udid=$(echo $udid)

appium_port=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${appium_port_position}`
export appium_port=$(echo $appium_port)

wda_port=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${wda_port_position}`
export wda_port=$(echo $wda_port)

mjpeg_port=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${mjpeg_port_position}`
export mjpeg_port=$(echo $mjpeg_port)

iwdp_port=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${iwdp_port_position}`
export iwdp_port=$(echo $iwdp_port)

stf_screen_port=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${stf_screen_port_position}`
export stf_screen_port=$(echo $stf_screen_port)

proxy_appium_port=`cat ${devices} | grep "$devicePattern" | cut -d '|' -f ${proxy_appium_port_position}`
export proxy_appium_port=$(echo $proxy_appium_port)

device_ip=""
if [[ -f "${metaDataFolder}/${udid}.txt" ]]; then
  device_ip=`cat ${metaDataFolder}/${udid}.txt`
fi
export device_ip=$(echo $device_ip)

