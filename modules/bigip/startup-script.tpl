#!/bin/bash

mkdir -p /config/cloud
cat << 'EOF' > /config/cloud/runtime-init-conf.yaml
---
runtime_parameters:
  - name: USER_NAME
    type: static
    value: ${admin_user}
  - name: ADMIN_PASS
    type: static
    value: ${admin_password}
  - name: TARGETHOST
    type: static
    value: ${targethost}
  - name: TARGETSSHKEY
    type: static
    value: ${targetsshkey}
pre_onboard_enabled:
  - name: provision_rest
    type: inline
    commands:
      - /usr/bin/setdb provision.extramb 500
      - /usr/bin/setdb restjavad.useextramb true
local-exec:
  description: DO via BIG-IQ
  post_onboard_enabled:
    - name: local_exec_onboarding
      type: inline
      commands:
        - json=$(curl -ks -X POST -d '{"username": '${admin_user}', "password": '${admin_password}', "loginProviderName":"local"}' https://${bigiq_mgmt_ip}/mgmt/shared/authn/login)
        - token=$(echo $json | jq -r '.token.token')
        - echo $token
        - onboard=$(curl -ks -X POST -H "X-F5-Auth-Token: $token" https://${bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding -d @do-bigiq.json)
        - echo $onboard | jq
        - taskid=$(echo $onboard | jq -r '.id' )
        - echo $taskid
        - x=1; while [ $x -le 30 ]; do STATUS=$(curl -s -k -X GET -H "X-F5-Auth-Token: $token" https://${bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding/task/$taskid); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
        - sleep 10
EOF

curl https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v1.2.1/dist/f5-bigip-runtime-init-1.2.1-1.gz.run -o f5-bigip-runtime-init-1.2.1-1.gz.run && bash f5-bigip-runtime-init-1.2.1-1.gz.run -- '--cloud aws'

f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf.yaml
