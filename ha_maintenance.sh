#!/bin/bash

################################################################################################
#   _    _            _____  ____    __  __       _       _                                    #
#  | |  | |   /\     |  __ \|  _ \  |  \/  |     (_)     | |                                   #
#  | |__| |  /  \    | |  | | |_) | | \  / | __ _ _ _ __ | |_ ___ _ __   __ _ _ __   ___ ___   #
#  |  __  | / /\ \   | |  | |  _ <  | |\/| |/ _` | | '_ \| __/ _ \ '_ \ / _` | '_ \ / __/ _ \  #
#  | |  | |/ ____ \  | |__| | |_) | | |  | | (_| | | | | | ||  __/ | | | (_| | | | | (_|  __/  #
#  |_|  |_/_/    \_\ |_____/|____/  |_|  |_|\__,_|_|_| |_|\__\___|_| |_|\__,_|_| |_|\___\___|  #
#                                                                                              #
################################################################################################

# Cleanup some old data from your home-assistant db
# And make sure there is a retained message from each area to all the person
# Name_from_Person1 and Name_from_Person2 must match your setup 
# The same is topic1 and topic2
# make sure you search and replace these strings in both scripts and they match your HA settings
# this script is shortend a lot my original script cleans a lot more than just the tracker heartbeats


## location of your homeassistant/home-assistant_v2.db
#var
db=/opt/homeassistant/home-assistant_v2.db

#some common used sql statements to make life easier and codelines shorter
older_events_than="time_fired < datetime('now','-"
older_states_than="created < datetime('now','-"

#mqtt stuff
server=ip.from.your.mqttserver
mqttuser=your_mqtt_username
mqttpass=your_mqtt_password
mosquitto_pub_path=$(which mosquitto_pub)
mqttp="$mosquitto_pub_path -h $server -p 1883 -u $mqttuser -P $mqttpass -t"
mosquitto_sub_path=$(which mosquitto_sub)
mqtts="$mosquitto_sub_path -h $server -p 1883 -u $mqttuser -P $mqttpass -t"
topic2=home/Garden
topic1=home/Fort-Smith

#dbsize before maintenance
dbsize=$(du -h $db|awk '{print $1}')
echo $dbsize

#stop HA
## make sure ha is offline while messin up the database
docker stop homeassistant

# make a backup just in case
cp $db ~/home-assistant_v2.db

##clean journal
journalctl --vacuum-time=10d

#sql statement for the event table
# to debug just remove the # in front of the select line and add a # to the delete line 
events() {
         #sqlite3 $db "SELECT * FROM events WHERE $statement;"
         sqlite3 $db "DELETE FROM events WHERE $statement;"
         }

#sql statement for the states table
# to debug just remove the # in front of the select line and add a # to the delete line
states() {
         #sqlite3 $db "SELECT * FROM states WHERE $statement;"
         sqlite3 $db "DELETE FROM states WHERE $statement;"
         }

## doit
## in my case the name from my wife (jacqueline) and my name (jan)starts withe the letters ja
## and there is no other sensor starts with ja
## so the single '%sensor.ja%' matches exact the two sensors maybe you need another expression or more lines
##
## not_home is always 0% the heartbest is 5%
## home is always 100%  the heartbest is 95%
## '%"state": "%5"%' gets both of them
statement="$older_events_than 1 days') AND event_data LIKE '%sensor.ja%' AND event_data LIKE '%"state": "%5"%'"
events

## yesterday is yesterday i am not the BND or STASI i just want to enable disable some automations
statement="$older_events_than 1 days') AND event_type = 'state_changed' AND event_data LIKE '%sensor.ja%%'"
events

## excactly like above
## not_home is always 0% the heartbest is 5%
## home is always 100%  the heartbest is 95%
## '%"state": "%5"%' gets both of them

statement="$older_states_than 1 days') AND entity_id LIKE '%sensor.ja%%' AND state LIKE '%5';"
states

## statistic did we clean up
unset dbsize
sqlite3 $db "vacuum;"
dbsize=$(du -h $db|awk '{print $1}')
echo $dbsize

## start homeassistent
docker start homeassistant

## make sure there is a retained message
timeout 2 $mqtts "$topic1/Name_from_Person1" -v -C 1 --retained-only |grep confidence ||$mqttp $topic1/Name_from_Person1 -m -r "{"confidence":"95"}"
timeout 2 $mqtts "$topic1/Name_from_Person2" -v -C 1 --retained-only |grep confidence ||$mqttp $topic1/Name_from_Person2 -m -r "{"confidence":"95"}"
timeout 2 $mqtts "$topic2/Name_from_Person1" -v -C 1 --retained-only |grep confidence ||$mqttp $topic2/Name_from_Person1 -m -r "{"confidence":"95"}"
timeout 2 $mqtts "$topic2/Name_from_Person2" -v -C 1 --retained-only |grep confidence ||$mqttp $topic2/Name_from_Person2 -m -r "{"confidence":"95"}"
