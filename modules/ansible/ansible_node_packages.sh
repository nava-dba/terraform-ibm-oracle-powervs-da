#!/bin/bash
############################################################
# OS_Support: RHEL only                                    #
# This bash script performs                                #
# - installation of packages                               #
# - ansible galaxy collections.                            #
#                                                          #
############################################################

GLOBAL_RHEL_PACKAGES="rhel-system-roles expect perl nfs-utils"
GLOBAL_GALAXY_COLLECTIONS="ibm.power_linux_sap:>=3.0.0,<4.0.0 ibm.power_aix:2.1.1 ibm.power_aix_oracle:1.3.2 ibm.power_aix_oracle_dba:2.0.8"

############################################################
# Start functions
############################################################

main::get_os_version() {
  if grep -q "Red Hat" /etc/os-release; then
    readonly LINUX_DISTRO="RHEL"
  else
    main::log_error "Unsupported Linux distribution. Only RHEL is supported."
  fi
  #readonly LINUX_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '\"' '{ print $2 }')
}

main::log_info() {
  local log_entry=${1}
  echo "INFO - ${log_entry}"
}

main::log_error() {
  local log_entry=${1}
  echo "ERROR - Deployment exited - ${log_entry}"
  exit 1
}

main::log_system_info() {
  local instance_id utc_time
  instance_id=$(dmidecode -s system-family)
  utc_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  main::log_info "Virtual server instance ID: ${instance_id}"
  main::log_info "System Time (UTC): ${utc_time}"
}

main::subscription_mgr_check_process() {

  main::log_info "Sleeping 30 seconds for all subscription-manager process to finish."
  sleep 30

  ## check if subscription-manager is still running
  while pgrep subscription-manager; do
    main::log_info "--- subscription-manager is still running. Waiting 10 seconds before attempting to continue"
    sleep 10s
  done

}

############################################################
# RHEL : Install Packages                                  #
############################################################
main::install_packages() {

  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then

    main::subscription_mgr_check_process

    ## hotfix for subscription-manager broken pipe error in next step
    subscription-manager list --available --all

    ## Install packages
    for package in $GLOBAL_RHEL_PACKAGES; do
      local count=0
      local max_count=3
      while ! dnf -y install "${package}"; do
        count=$((count + 1))
        sleep 3
        # shellcheck disable=SC2317
        if [[ ${count} -gt ${max_count} ]]; then
          main::log_error "Failed to install ${package}"
          break
        fi
      done
    done

    ## Download and install collections from ansible-galaxy

    for collection in $GLOBAL_GALAXY_COLLECTIONS; do
      local count=0
      local max_count=3
      while ! ansible-galaxy collection install "${collection}" -f; do
        count=$((count + 1))
        sleep 3
        # shellcheck disable=SC2317
        if [[ ${count} -gt ${max_count} ]]; then
          main::log_error "Failed to install ansible galaxy collection ${collection}"
          break
        fi
      done
    done

    ansible-galaxy collection install -r '/root/.ansible/collections/ansible_collections/ibm/power_linux_sap/requirements.yml' -f
    main::log_info "All packages installed successfully"
  fi

}

############################################################
# Setup proxy                                              #
############################################################
main::setup_proxy() {
  local proxy_url="http://${squid_server_ip}:3128"

  # Determine correct bashrc file
  if [[ -f /etc/bashrc ]]; then
    bashrc_file="/etc/bashrc"
  elif [[ -f /etc/bash.bashrc ]]; then
    bashrc_file="/etc/bash.bashrc"
  else
    main::log_error "No global bashrc file found!"
    return 1
  fi

  # Export for current shell
  export http_proxy="$proxy_url"
  export https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url"
  export HTTPS_PROXY="$proxy_url"
  export no_proxy="localhost,127.0.0.1,::1"

  # Clean existing entries
  sed -i '/http_proxy=/d' "$bashrc_file"
  sed -i '/https_proxy=/d' "$bashrc_file"
  sed -i '/HTTP_PROXY=/d' "$bashrc_file"
  sed -i '/HTTPS_PROXY=/d' "$bashrc_file"
  sed -i '/no_proxy=/d' "$bashrc_file"

  # Append new entries
  cat <<EOF >> "$bashrc_file"

# Proxy Settings
export http_proxy=$proxy_url
export https_proxy=$proxy_url
export HTTP_PROXY=$proxy_url
export HTTPS_PROXY=$proxy_url
export no_proxy=localhost,127.0.0.1,::1
EOF

  main::log_info "Proxy configured in $bashrc_file: $proxy_url"
}

#######################################################################################################
# Call rhel-cloud-init.sh To register your LPAR with the RHEL subscription in PowerVS Private    #
#######################################################################################################

main::run_cloud_init() {
  squid_ip="${squid_server_ip}"
  FILE_NAME="/usr/share/powervs-fls/powervs-fls-readme.md"
  if [ -s "$FILE_NAME" ]; then
    echo "File '$FILE_NAME' exists and has a size greater than zero."
    echo -e $(subscription-manager status)
    cloud_init_cmd=`grep '\-t RHEL' $FILE_NAME` 
    cloud_init_cmd_new=$(echo "$cloud_init_cmd" | sed "s/Private.proxy.IP.address/$squid_ip/g")
    $cloud_init_cmd_new
    PID=$!
    echo $'\nWaiting for background script to complete ....\n' 
    wait $PID
  
    echo -e $(subscription-manager status)
    echo -e $(dnf repolist)
    echo -e "FLS registration completed successfully."
  else
    echo -e "FLS registration failed please refer https://www.ibm.com/docs/en/power-virtual-server?topic=linux-full-subscription-power-virtual-server-private-cloud "
    exit 1
  fi
}


############################################################
# Main start here                                          #
############################################################
main::setup_proxy
main::get_os_version
main::log_system_info
main::run_cloud_init
main::install_packages

