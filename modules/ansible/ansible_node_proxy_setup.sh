#!/bin/bash
############################################################
# OS_Support: RHEL only                                    #
# This bash script performs                                #
# - installation of packages                               #
# - ansible galaxy collections.                            #
#                                                          #
############################################################

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
# Setup proxy                                              #
############################################################
main::setup_proxy() {
  local proxy_url="http://${squid_server_ip}:3128"

  # Export for current shell (so script itself uses proxy)
  export http_proxy="$proxy_url"
  export https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url"
  export HTTPS_PROXY="$proxy_url"

  # Persist in /etc/environment for non-interactive shells
  if ! grep -q "http_proxy" /etc/environment; then
    cat <<EOF >> /etc/environment
http_proxy=$proxy_url
https_proxy=$proxy_url
HTTP_PROXY=$proxy_url
HTTPS_PROXY=$proxy_url
no_proxy=localhost,127.0.0.1,::1
EOF
  fi

  # Persist in /etc/profile for interactive shells
  if ! grep -q "http_proxy" /etc/profile; then
    cat <<EOF >> /etc/profile

# Proxy Settings
export http_proxy=$proxy_url
export https_proxy=$proxy_url
export HTTP_PROXY=$proxy_url
export HTTPS_PROXY=$proxy_url
export no_proxy=localhost,127.0.0.1,::1
EOF
  fi

  main::log_info "Proxy configured: $proxy_url"
}

############################################################
# Main start here                                          #
############################################################
main::get_os_version
main::log_system_info
main::setup_proxy
