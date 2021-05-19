#!/bin/sh
###################################################################################
#  _     _            _              _   _     _                  _
# | |   | |          | |            | | | |   | |                | |
# | |__ | |_   _  ___| |_ ___   ___ | |_| |__ | |_ _ __ __ _  ___| | _____ _ __
# | '_ \| | | | |/ _ \ __/ _ \ / _ \| __| '_ \| __| '__/ _` |/ __| |/ / _ \ '__|
# | |_) | | |_| |  __/ || (_) | (_) | |_| | | | |_| | | (_| | (__|   <  __/ |
# |_.__/|_|\__,_|\___|\__\___/ \___/ \__|_| |_|\__|_|  \__,_|\___|_|\_\___|_|
#
##################################################################################

#  Fetch known bluetoothdevices and tell HA over MQTT if and who is home right now
#  made for more than one Bluetooth tracker in my case Home and the Garden
#  but only one system is allowed to publish the final "person not home" to HA
#
#  This script needs some ha sensors and another script that cleans the database at night
#
#  Thats because it uses retained mqtt messages and if things go wrong we can see that in ha
#

#edit to your setup
#credentials
server=ip.from.your.haserver

mqttuser=your_mqtt_username
mqttpass=your_mqtt_password

#apitoken
api_key=your_long_live_ha_api_token
api_url=http://$server:ha_port/api

#mosquitto
system=$(hostname)
mosquitto_pub_path=$(which mosquitto_pub)
mqttp="$mosquitto_pub_path -h $server -p 1883 -u $mqttuser -P $mqttpass -t"
mosquitto_sub_path=$(which mosquitto_sub)
mqtts="$mosquitto_sub_path -h $server -p 1883 -u $mqttuser -P $mqttpass -t"

# topic1 is the pub topic for the actual system
# topic2 is the sub topic filled by another system to check the persons homestate
# used to doublecheck if a person is in the near of another scanner
# maintopic is home
# subtopic is the area that is scanned (Fort-Smith or Garden)
# subsubtopic is the actual person

# im my case the system with the hostname garden is responsible for the area garden
if [ "$system" = "garden" ]
   then
   topic2=home/Fort-Smith
   topic1=home/Garden
else
   topic2=home/Garden
   topic1=home/Fort-Smith
fi

# debug
# echo $system

# bluetooth must be active
hciconfig hci0 up

check_status() {
        # in my case the MQTT Topic is jan but my person in HA is Jan instead of "fixin this in mqtt i decided to fix it here.
        Mperson=`echo $person|tr "[:upper:]" "[:lower:]"`
        home=$(hcitool name $bluetooth)
        if [ ! "$home" =  "" ]
           then
           state=home
           # make heartbeat
           $mqttp $topic1/$Mperson -r -m '{"confidence":"95"}'
           # set state
           $mqttp $topic1/$Mperson -r -m '{"confidence":"100"}'
        else
           doublecheck=$($mqtts $topic2/$Mperson -C 1|cut -d '"' -f4)
           if [ "$doublecheck" -gt "90" ]
              then
              state=home
           else
              state=not_home
           fi
           # make heartbeat
           $mqttp $topic1/$Mperson -r -m '{"confidence":"5"}'
           # set state
           $mqttp $topic1/$Mperson -r -m '{"confidence":"0"}'
        fi
        if [ "$system" = "bigbox" ]
           then
           json_template_tracker
           set_tracker_status
        fi
        }

json_template_tracker() {
        template_tracker='{"state":"%s","attributes":{"source_type":"bluetooth","friendly_name":"%s"}}'
        json_string=$(printf "$template_tracker" "$state" "$person")
        }

set_tracker_status() {
        echo $person $state
        curl --silent --output /dev/null "$api_url/states/device_tracker.$person" -H "authorization: Bearer $api_key" --data-raw $json_string
        }

#1
person=Name_from_Person1
bluetooth=CA:FE:4D:JA:NG:01 # his bluetooth Mac address
check_status

#2
person=Name_from_Person2
bluetooth=CA:FE:4D:JA:NG:02 # her bluetooth Mac address
check_status
