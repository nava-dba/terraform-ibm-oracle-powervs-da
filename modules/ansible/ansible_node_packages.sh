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

    ## enable repository for RHEL sap roles
    subscription-manager repos --enable="rhel-$(rpm -E %rhel)-for-$(uname -m)-sap-solutions-rpms"

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
# Call rhel-cloud-init.sh To register your LPAR with the RHEL subscription on the satellite server    #
#######################################################################################################

main::run_cloud_init() {
  # Validate that all five required environment variables are provided
  if [[ -z "$ACTIVATION_KEY" || -z "$REDHAT_CAPSULE_SERVER" || -z "$squid_server_ip" || -z "$ORG" || -z "$FLS_DEPLOYMENT" ]]; then
    main::log_info "Skipping /usr/local/bin/rhel-cloud-init.sh — one or more required environment variables are missing."
    main::log_info "Expected: ACTIVATION_KEY, REDHAT_CAPSULE_SERVER, PROXY, ORG, FLS_DEPLOYMENT"
    return 0
  fi


local PROXY="${squid_server_ip}:3128"

  main::log_info "Running /usr/local/bin/rhel-cloud-init.sh with provided environment variables..."
  main::log_info "Using:"
  main::log_info "  ACTIVATION_KEY        = *************** (hidden for security)"
  main::log_info "  REDHAT_CAPSULE_SERVER = $REDHAT_CAPSULE_SERVER"
  main::log_info "  PROXY                 = $PROXY"
  main::log_info "  ORG                   = $ORG"
  main::log_info "  FLS_DEPLOYMENT        = $FLS_DEPLOYMENT"

  /usr/local/bin/rhel-cloud-init.sh \
    -a "$ACTIVATION_KEY" \
    -u "$REDHAT_CAPSULE_SERVER" \
    -p "$PROXY" \
    -o "$ORG" \
    -t "$FLS_DEPLOYMENT"

  rc=$?
  case $rc in
    0)
      main::log_info "rhel-cloud-init.sh executed successfully (exit code 0)."
      ;;
    2)
      main::log_info "rhel-cloud-init.sh returned 2 due to known script issue — treating as success."
      ;;
    *)
      main::log_error "rhel-cloud-init.sh failed with exit code $rc."
      ;;
  esac
}


############################################################
# Main start here                                          #
############################################################
main::setup_proxy
main::get_os_version
main::log_system_info
main::run_cloud_init
main::install_packages

