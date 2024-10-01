#!/bin/bash
if [ -f /config/startup_finished ]; then
    exit
fi
if [ -f /config/first_run_flag ]; then
   echo "Skip first run steps, already ran."
else
   /usr/bin/mkdir -p  /var/log/cloud /config/cloud /var/lib/cloud/icontrollx_installs /var/config/rest/downloads
   LOG_FILE=/var/log/cloud/startup-script-pre-nic-swap.log
   /usr/bin/touch $LOG_FILE
   npipe=/tmp/$$.tmp
   /usr/bin/trap "rm -f $npipe" EXIT
   /usr/bin/mknod $npipe p
   /usr/bin/tee <$npipe -a $LOG_FILE /dev/ttyS0 &
   exec 1>&-
   exec 1>$npipe
   exec 2>&1
   cat << 'EOF' > /config/cloud/runtime-init-conf.yaml
---
controls:
  extensionInstallDelayInMs: 60000
runtime_parameters:
  - name: USER_NAME
    type: static
    value: ${bigip_username}
  - name: SSH_KEYS
    type: static
    value: "${ssh_keypair}"
  - name: HOST_NAME
    type: metadata
    metadataProvider:
        environment: gcp
        type: compute
        field: name
EOF
if ${gcp_secret_manager_authentication}; then
   cat << 'EOF' >> /config/cloud/runtime-init-conf.yaml
  - name: ADMIN_PASS
    type: secret
    secretProvider:
      environment: gcp
      type: SecretsManager
      version: latest
      secretId: ${bigip_password}
pre_onboard_enabled: []
EOF
else
   cat << 'EOF' >> /config/cloud/runtime-init-conf.yaml
  - name: ADMIN_PASS
    type: static
    value: ${bigip_password}
pre_onboard_enabled: []
EOF
fi
cat /config/cloud/runtime-init-conf.yaml > /config/cloud/runtime-init-conf-backup.yaml
cat << 'EOF' >> /config/cloud/runtime-init-conf.yaml
extension_packages: 
  install_operations:
    - extensionType: do
      extensionVersion: ${DO_VER}
      extensionUrl: ${DO_URL}
    - extensionType: as3
      extensionVersion: ${AS3_VER}
      extensionUrl: ${AS3_URL}
    - extensionType: ts
      extensionVersion: ${TS_VER}
      extensionUrl: ${TS_URL}
    - extensionType: cf
      extensionVersion: ${CFE_VER}
      extensionUrl: ${CFE_URL}
    - extensionType: fast
      extensionVersion: ${FAST_VER}
      extensionUrl: ${FAST_URL}
extension_services:
  service_operations:
    - extensionType: do
      type: inline
      value:
        schemaVersion: 1.0.0
        class: Device
        async: true
        Common:
          class: Tenant
          hostname: '{{{HOST_NAME}}}.com'
          myNtp:
            class: NTP
            servers:
              - 169.254.169.254
            timezone: UTC
          myDns:
            class: DNS
            nameServers:
              - 169.254.169.254
          myProvisioning:
            class: Provision
            ltm: nominal
          admin:
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
          '{{{USER_NAME}}}':
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
post_onboard_enabled: []
EOF
cat << 'EOF' >> /config/cloud/runtime-init-conf-backup.yaml
extension_services:
  service_operations:
    - extensionType: do
      type: inline
      value:
        schemaVersion: 1.0.0
        class: Device
        async: true
        Common:
          class: Tenant
          hostname: '{{{HOST_NAME}}}.com'
          myNtp:
            class: NTP
            servers:
              - 169.254.169.254
            timezone: UTC
          myDns:
            class: DNS
            nameServers:
              - 169.254.169.254
          myProvisioning:
            class: Provision
            ltm: nominal
          admin:
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
          '{{{USER_NAME}}}':
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
post_onboard_enabled: []
EOF
   /usr/bin/cat << 'EOF' > /config/nic-swap.sh
   #!/bin/bash
   /usr/bin/touch /config/nic_swap_flag
   /usr/bin/setdb provision.managementeth eth1
   /usr/bin/setdb provision.extramb 1000 || true
   /usr/bin/setdb provision.restjavad.extramb 1384 || /usr/bin/setdb restjavad.useextramb true || true
   /usr/bin/setdb iapplxrpm.timeout 300 || true
   /usr/bin/setdb icrd.timeout 180 || true
   /usr/bin/setdb restjavad.timeout 180 || true
   /usr/bin/setdb restnoded.timeout 180 || true
   reboot
EOF
   /usr/bin/cat << 'EOF' > /config/startup-script.sh
   #!/bin/bash
   LOG_FILE=/var/log/cloud/startup-script-post-swap-nic.log
   touch $LOG_FILE
   npipe=/tmp/$$.tmp
   /usr/bin/trap "rm -f $npipe" EXIT
   /usr/bin/mknod $npipe p
   /usr/bin/tee <$npipe -a $LOG_FILE /dev/ttyS0 &
   exec 1>&-
   exec 1>$npipe
   exec 2>&1
   if ${NIC_COUNT} ; then
       # Need to remove existing and recreate a MGMT default route as not provided by DHCP on 2nd NIC Route name must be same as in DO config.
       source /usr/lib/bigstart/bigip-ready-functions
       wait_bigip_ready
       tmsh modify sys global-settings mgmt-dhcp disabled
       tmsh delete sys management-route all
       tmsh delete sys management-ip all
       wait_bigip_ready
       # Wait until a little more until dhcp/chmand is finished re-configuring MGMT IP w/ "chmand[4267]: 012a0003:3: Mgmt Operation:0 Dest:0.0.0.0"
       sleep 15
       MGMT_GW=$(egrep static-routes /var/lib/dhclient/dhclient.leases | tail -1 | grep -oE '[^ ]+$' | tr -d ';')
       SELF_IP_MGMT=$(egrep fixed-address /var/lib/dhclient/dhclient.leases | tail -1 | grep -oE '[^ ]+$' | tr -d ';')
       MGMT_BITMASK=$(egrep static-routes /var/lib/dhclient/dhclient.leases | tail -1 | cut -d ',' -f 2 | cut -d ' ' -f 1 | cut -d '.' -f 1)
       MGMT_NETWORK=$(egrep static-routes /var/lib/dhclient/dhclient.leases | tail -1 | cut -d ',' -f 2 | cut -d ' ' -f 1 | cut -d '.' -f 2-4).0
       echo "MGMT_GW - "
       echo $MGMT_GW
       echo "SELF_IP_MGMT - "
       echo $SELF_IP_MGMT
       echo "MGMT_BITMASK - "
       echo $MGMT_BITMASK
       echo "MGMT_NETWORK - "
       echo $MGMT_NETWORK
       tmsh create sys management-ip $SELF_IP_MGMT/32
       echo "tmsh list sys management-ip - "
       tmsh list sys management-ip
       tmsh create sys management-route mgmt_gw network $MGMT_GW/32 type interface
       tmsh create sys management-route mgmt_net network $MGMT_NETWORK/$MGMT_BITMASK gateway $MGMT_GW
       tmsh create sys management-route defaultManagementRoute network default gateway $MGMT_GW mtu 1460
       echo "tmsh list sys management-route - "
       tmsh list sys management-route
       tmsh modify sys global-settings remote-host add { metadata.google.internal { hostname metadata.google.internal addr 169.254.169.254 } }
       tmsh save /sys config
   fi
   for i in {1..30}; do
    curl -fv --retry 1 --connect-timeout 5 -L ${INIT_URL} -o "/var/config/rest/downloads/f5-bigip-runtime-init.gz.run" && break || sleep 10
   done
   # install and run f5-bigip-runtime-init
   bash /var/config/rest/downloads/f5-bigip-runtime-init.gz.run -- '--cloud gcp'
   /usr/bin/cat /config/cloud/runtime-init-conf.yaml
   /usr/local/bin/f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf.yaml
   sleep 5
   /usr/local/bin/f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf-backup.yaml
   /usr/bin/touch /config/startup_finished
EOF
   /usr/bin/chmod +x /config/nic-swap.sh
   /usr/bin/chmod +x /config/startup-script.sh
   MULTI_NIC="${NIC_COUNT}"
   /usr/bin/touch /config/first_run_flag
fi
if ${NIC_COUNT} ; then
   nohup /config/nic-swap.sh &
else
   /usr/bin/touch /config/nic_swap_flag
fi
if [ -f /config/nic_swap_flag ]; then
   nohup /config/startup-script.sh &
fi