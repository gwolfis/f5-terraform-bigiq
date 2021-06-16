#!/bin/bash

mkdir -p /config/cloud
cat << 'EOF' > /config/cloud/runtime-init-conf.yaml
---
runtime_parameters:
  - name: USER_NAME
    type: static
    value: ${user_name}
  - name: ADMIN_PASS
    type: static
    value: ${user_password}
pre_onboard_enabled:
  - name: provision_rest
    type: inline
    commands:
      - /usr/bin/setdb provision.extramb 500
      - /usr/bin/setdb restjavad.useextramb true
post_onboard_enabled:
    - name: local_exec_onboarding
      type: inline
      join: "\n"
      commands:
        - json=$(curl -ks -X POST -d '{"username":"${user_name}","password":"${user_password}","loginProviderName":"local"}' https://${bigiq_mgmt_ip}/mgmt/shared/authn/login)
        - token=$(echo $json | jq -r '.token.token')
        - echo $token;
        - onboard=$(curl -ks -X POST -H "X-F5-Auth-Token: $token" https://${bigiq_mgmt_ip}/mgmt/shared/declarative-onboarding -d @do-bigiq.json)
        - echo $onboard | jq
        - taskid=$(echo $onboard | jq -r '.id' )
        - echo $taskid
EOF

curl https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v1.2.1/dist/f5-bigip-runtime-init-1.2.1-1.gz.run -o f5-bigip-runtime-init-1.2.1-1.gz.run && bash f5-bigip-runtime-init-1.2.1-1.gz.run -- '--cloud aws'

f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf.yaml
