#!/bin/bash

# BIGIQ=3.65.66.216
# #BIGIQ=10.42.1.92
# USER=admin
# PASS=F5twister2020!

BIGIQ=${bigiq_mgmt_ip}
USER=${user_name}
PASS=${user_password}
CREDS="admin:"$user_password

# CHECK TO SEE NETWORK IS READY
CNT=0
while true
do
  STATUS=$(curl -s -k -I .com | grep HTTP)
  if [[ $STATUS == *"200"* ]]; then
    echo "Got 200! VE is Ready!"
    break
  elif [ $CNT -le 6 ]; then
    echo "Status code: $STATUS  Not done yet..."
    CNT=$[$CNT+1]
  else
    echo "GIVE UP..."
    break
  fi
  sleep 10
done

sleep 60

echo $BIGIQ

json=$(curl -ks -X POST -d '{"username": '$USER', "password": '$PASS', "loginProviderName":"local"}' https://$BIGIQ/mgmt/shared/authn/login)

token=$(echo $json | jq -r '.token.token')

echo $token

onboard=$(curl -ks -X POST -H "X-F5-Auth-Token: $token" https://$BIGIQ/mgmt/shared/declarative-onboarding -d @do-bigiq.json)

echo $onboard | jq

taskid=$(echo $onboard | jq -r '.id' )

echo $taskid

status=$(curl -s -k -X GET -H "X-F5-Auth-Token: $token" https://$BIGIQ/mgmt/shared/declarative-onboarding/task/$taskid)

Check DO Task
CNT=0
while true
do
  STATUS=$(curl -u $CREDS -X GET -s -k https://$BIGIQ/mgmt/shared/declarative-onboarding/task)
  if ( echo $STATUS | grep "OK" ); then
    echo -e "\n"$(date) "DO task successful"
    break
  elif [ $CNT -le 30 ]; then
    echo -e "\n"$(date) "DO task working..."
    CNT=$[$CNT+1]
  else
    echo -e "\n"$(date) "DO task fail"
    break
  fi
  sleep 10
done