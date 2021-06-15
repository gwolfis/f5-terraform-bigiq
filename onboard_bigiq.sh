#!/bin/bash

BIGIQ=3.65.66.216
#BIGIQ=10.42.1.92
USER=admin
PASS=F5twister2020!



#sleep 420

echo $BIGIQ

json=$(curl -ks -X POST -d '{"username": '$USER', "password": '$PASS', "loginProviderName":"local"}' https://$BIGIQ/mgmt/shared/authn/login)

token=$(echo $json | jq -r '.token.token')

echo $token

onboard=$(curl -ks -X POST -H "X-F5-Auth-Token: $token" https://$BIGIQ/mgmt/shared/declarative-onboarding -d @do-bigiq.json)

echo $onboard | jq

taskid=$(echo $onboard | jq -r '.id' )

echo $taskid

status=$(curl -s -k -X GET -H "X-F5-Auth-Token: $token" https://$BIGIQ/mgmt/shared/declarative-onboarding/task/$taskid)

until echo $status | grep "OK"
do
   echo "Status=$status BIG-IP onboarding via BIG-IQ in progress"
   sleep 10
done
echo "Status=$status Onboarding via BIG-IQ has finished"


#url -s -k -X GET https://${var.bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task -u ${var.admin_user}:${var.admin_password})

#info=$(curl -ks -X GET -H "X-F5-Auth-Token: $token" https://$BIGIQ/mgmt/shared/declarative-onboarding/info)

#echo "$info" | jq
