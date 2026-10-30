#!/bin/bash

# This file contains paths pointing to some binaries whose paths
# may not already be known to current shell, hence source it before execution
DOT_PROFILE="${HOME}/.profile"
. ${DOT_PROFILE}
# This file contains configurables like versions of certain tools, container images,
# flags, etc. IXOPS_CONFIG_YAML lets deploy.sh point at a merged copy.
CONFIG_YAML=${IXOPS_CONFIG_YAML:-$(pwd)/config.yaml}
AUTH_YAML=$(pwd)/auth.yaml
# This file contains all the stdout and stderr generated during
# execution; the new contents are appended everytime script is executed
IXOPS_LOG=$(pwd)/ixops.log

check_required_auth_value() {
    local cfg="${1}"
    local key="${2}"
    local value

    value=$(awk -v key="${key}" '
        BEGIN { in_opts=0 }
        /^opts:/ { in_opts=1; next }
        in_opts && $0 ~ "^  " key ":" {
            value=$0
            sub("^  " key ":[[:space:]]*", "", value)
            gsub(/^["\047]+|["\047]+$/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
        in_opts && /^[^[:space:]]/ { exit }
    ' "${cfg}")

    printf '%s' "${value}"
}

check_github_credentials() {
    local cfg="${AUTH_YAML:-$(pwd)/auth.yaml}"
    local github_user github_pat

    if [ ! -f "${cfg}" ]; then
        echo "ERROR: ${cfg} not found. Create auth.yaml from auth-template.yaml before running ixops." >&2
        exit 1
    fi

    github_user=$(check_required_auth_value "${cfg}" "github-user")
    github_pat=$(check_required_auth_value "${cfg}" "github-pat")

    if [ -z "${github_user}" ] || [ -z "${github_pat}" ]; then
        echo "ERROR: Please set your GitHub username and personal access token in the opts section of ${cfg} before executing any ixops command." >&2
        echo "auth.yaml should look like this:" >&2
        echo "Example:" >&2
        echo "opts:" >&2
        echo "  github-user: \"your-github-username\"" >&2
        echo "  github-pat: \"your-github-personal-access-token\"" >&2
        exit 1
    fi
}

validate_required_credentials() {
    check_github_credentials
}

validate_required_credentials

DOT_KUBE="${HOME}/.kube"
DOCKER_CONFIG="${HOME}/.docker/config.json"
# Runtime fallback for the Google service-account JSON; if the file is missing,
# the script can recreate it from this base64 payload instead of keeping the raw
# private key in the repository. A shell environment variable still wins if set.
GCLOUD_SA_JSON_B64="${GCLOUD_SA_JSON_B64:-ewogICJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsCiAgInByb2plY3RfaWQiOiAia3QtbnRzLWF0aGVuYS1kZXYiLAogICJwcml2YXRlX2tleV9pZCI6ICIyZDIyZmZhMmMxOTE4ZGU0YWMxOTQ3MDBkMmZmNGMwMzQzNjE3NTFjIiwKICAicHJpdmF0ZV9rZXkiOiAiLS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tXG5NSUlFdlFJQkFEQU5CZ2txaGtpRzl3MEJBUUVGQUFTQ0JLY3dnZ1NqQWdFQUFvSUJBUUMwak0wbVBVc0FhY3JVXG5MVklRb1p2ZlhLVjBTaTcxYURINHM2aDlzckhvMm82VHFPME1mb3VZTEF3RkkyTXVLL1oyd3czcHdUc0tndFVmXG5wTUN4b2ZGZkhGeDBFZ3B4eU11Y1JyYkM3UVkrOHQ1eXlPTmgvZWdJR1pxR2hNMjh1cEhmYXZ3QjczOTZMVFg2XG5wV1hjc0QvNlhYb3l0Q0hpTmNiZkErQmxNd01teDVldlVUUnZXQVVyallSR0J4NnNDaHdIdllaUHIwZnVDY2xtXG5PK3RXUFVTNHl5Mmk0RlA3aFZ5N3BVSDRGNGs1UE0xSHZCS2xMQm5zZDRnaFAzUTNZUm04VmU4aXlSQjJ5YkpXXG5mWHVJS2dsZDZ5Z3BkVUM2NWsyQ1Q5b1pOajdsYzNraU82eHVyRDlWTGFBOC91YmNadHZ3N3RmQXZsMlFGcFRpXG44M05ZcmgxUEFnTUJBQUVDZ2dFQVRBL3pUMVJNR0JqNWo0aW1SWVpuN2VJUWZCelNpcVdDUStXZ0twQlJIaW1SXG5Ia2p3MEs0eExnTUViMWU0clZkdEJoeG5iSjV3dXAxaW51bWdHbFdBbzlLRmFvcTlKckZ5Z2R4U20yMFNrQXR1XG5Sb28yTE82MFJWRlFCYkxHSCtlems1MTFISFdpelR4bHZMbllYM0JMQzdVOHlVYVU3Y0U5RG5BS0pXZ253RHBvXG5mWjE2TExscEJ1Ry9qTWczLzVBYkNGazZiZjFrN1JDRWN6cFRnL1MxbUdpTlNVclJ5VnM2RDZCdU1rVDFvNWttXG5zQ1pYaHk3WTExTDlnWTFoc0xXRCsyV3BiSFlEQ1l1NTFNLzJZOXNENFNjdkl6Vm4wS2JMT0FuMW9VblRaRkJWXG5hRFFCdnJjZnlVNzFidFdoU1M0RE12bGJjQzlMdDZlaEFqN29ONFJEelFLQmdRRHdKOUoyOFUydk42d0srTHh2XG5YaHNwcDBHT2FaNVhaVXZIVkoxdmx5V0ViZjM4a1haalRxVFFRcklKLzNvcW9CbFBuQU4vVnUrTWE5MTlFVlFTXG5CcFAvRWxWZndRTG1Wc01qUW5rNmhNTm00L1lwb0tOUC8wK3VQNWZoc0FNWTdxNVdha1pBdWVYYzV1OFl4ZDVVXG5FdkVEVXkrMFFMY3ZFT1ptclJiVHF2am53d0tCZ1FEQWRrRDNZR3R0VFVvdEFwMm1TZzFSSC8rZkQxeUZ3R2RSXG5XbGFROEtWVDAwTnFLSUZVRmRMM084elk3eWFwMVFHZ1U4NS9jSlBCM1lkcjcvdUdMekg0UGZBM0JGcFpCeUNkXG5aaEZtWjY0cG85RE5ZMmdPZkpRTTM0WDJ4dGd3OXM0WVdob1h0MzR1blI0UXAxWlowZ3haT0treE44Z2h1L0RlXG5YVUF5cThVbmhRS0JnQ01na0FaWjBWVVp2WTUxUjRxNnB4cDJubjRvTU1MenpCdkI0cTFaM0dEOGZiUWR5c1ZIXG4wWStzMGNIb25vUHhtd0lyL2M3NGRsMkJ3WW56cU9waUQrKzFUTXVPdmMvWFRQK3hUMjRoMFRzUmlRWVp1d21PXG5mS2N1SWhjZTJiVWg1Rm83ZlQ4bWNkclg1STBwRkJZVUZ6QzNVRGo3WmsvNkZ0bFo1QWJkOFQ1bEFvR0JBS2lyXG4rcXZTbU5PbUZRZjFidXk1b1lvam5RZHRrd3kxWHRieGNVUjlZcWRnVTRqS0R1MytZbkhDdXZpMFB4SkFWN2lIXG5Pa1orQjBDMFFXYmJYM2h1REVFZkoxTlFRVTRjN1B5RTQyTDRJcTdqbnE4aUc2UDJrbG5sMjZZM0JtbURJNFE4XG5Fdm9PR2t3SDdyMXhxai8xMGxTdlQ3aU94cHFwOTZNcDNvV0ovTE54QW9HQVNCejgwUTc4THBUTTU0VVQ0TTRPXG5Jb3U3RG53QlVrd0RPRWdEaHU3RnpRMlkxUVc5ZnVLRzJ5RnZMeUtIcVJ2eW1tYllHYUhTWTBnYUt5Vk5DWEJjXG5ROUpHaEE3Y2pmNUpIZm9wdjFXQkN2dFFHMHU0WHVobkdkNElpYk9ZZ3pnd0gyT3NZMFdhMDY2QmtpWHk3OFVDXG5mRGlETXNkV0JvazQ1SWtQSFJDam9WVT1cbi0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS1cbiIsCiAgImNsaWVudF9lbWFpbCI6ICJpeGlhLWMtYXV0b21hdGlvbkBrdC1udHMtYXRoZW5hLWRldi5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSIsCiAgImNsaWVudF9pZCI6ICIxMDk1Nzk3ODQ0ODU2NzY0MjI0NTkiLAogICJhdXRoX3VyaSI6ICJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20vby9vYXV0aDIvYXV0aCIsCiAgInRva2VuX3VyaSI6ICJodHRwczovL29hdXRoMi5nb29nbGVhcGlzLmNvbS90b2tlbiIsCiAgImF1dGhfcHJvdmlkZXJfeDUwOV9jZXJ0X3VybCI6ICJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9vYXV0aDIvdjEvY2VydHMiLAogICJjbGllbnRfeDUwOV9jZXJ0X3VybCI6ICJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9yb2JvdC92MS9tZXRhZGF0YS94NTA5L2l4aWEtYy1hdXRvbWF0aW9uJTQwa3QtbnRzLWF0aGVuYS1kZXYuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLAogICJ1bml2ZXJzZV9kb21haW4iOiAiZ29vZ2xlYXBpcy5jb20iCn0KCg==}"

# GO_RELEASE/YQ_RELEASE stay hardcoded here rather than living in
# config.yaml like the other pinned tool versions: configq() shells out to
# `yq`, and get_go()/get_yq() are what install Go and yq in the first place
# (get_yq() builds yq from source via `go install`, which is why get_go()
# runs first in common_install()) -- on a fresh machine neither exists yet,
# so config.yaml can't be read until after these two have already run.
GO_RELEASE="1.26.0"
# GO_SOURCE is resolved dynamically based on the host architecture.
YQ_RELEASE="v4.44.3"
YQ_SOURCE="github.com/mikefarah/yq/v4@${YQ_RELEASE}"
VERSION_INFO="$(pwd)/version_info.json"
TESTCASES_INFO_FILE="$(pwd)/testcases_info.json"
# TESTCASES_INFO_FILE="$(pwd)/fp-essentials/sample_testcases_info.json"
VENDOR_CRED_FILE="$(pwd)/fp-essentials/vendor_cred.json"
# update for any release using
# curl -kLO https://github.com/open-traffic-generator/ixia-c/releases/download/v0.0.1-2994/versions.yaml
VERSIONS_YAML="versions.yaml"
VETH_A="veth-a"
VETH_Z="veth-z"
# additional member ports for LAG
VETH_B="veth-b"
VETH_C="veth-c"
VETH_X="veth-x"
VETH_Y="veth-y"

NOKIA_SRL_OPERATOR_VERSION="0.4.6"
NOKIA_SRL_OPERATOR_YAML="https://github.com/srl-labs/srl-controller/config/default?ref=v${NOKIA_SRL_OPERATOR_VERSION}"
ARISTA_CEOS_VERSION="4.29.1F-29233963"
ARISTA_CEOS_IMAGE="ghcr.io/open-traffic-generator/ceos"

OPENCONFIG_MODELS_REPO=https://github.com/openconfig/public.git
OPENCONFIG_MODELS_COMMIT=5ca6a36

APT_UPDATE=true

test_case_file=""
retry=2
# accumulates messages from warn_noncritical() for a final recap at exit,
# so a soft failure early in a long run doesn't get lost among later output
NONCRIT_WARNINGS=""

configq() {
    # echo is needed to further evaluate the 
    # contents extracted from configuration
    eval echo $(yq "${@}" ${CONFIG_YAML})
}

authq() {
    # echo is needed to further evaluate the 
    # contents extracted from configuration
    eval echo $(yq "${@}" ${AUTH_YAML})
}

configqf() {
    eval echo $(yq ${1} ${2})
}

get_testcases_info() {
    test_case_file=$(configqf . $TESTCASES_INFO_FILE)
}

check_cmd() {
    eval "${@}" >> "${IXOPS_LOG}" 2>&1
}

get_seconds() {
    date +%s
}

get_arch() {
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    case "${arch}" in
        amd64|x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        armhf|armv7l)
            echo "armv6l"
            ;;
        *)
            echo "${arch}"
            ;;
    esac
}

resolve_docker_arch() {
    case "$(get_arch)" in
        amd64|arm64)
            echo "$(get_arch)"
            ;;
        *)
            err "Unsupported architecture for docker install: $(get_arch)"
            return 1
            ;;
    esac
}

resolve_go_source() {
    echo "https://dl.google.com/go/go${GO_RELEASE}.linux-$(get_arch).tar.gz"
}

install_keysight_certs() {
    rm -rf Keysight_Root.crt
    curl -kLO https://generic-virtual-athena.artifactorylbj.it.keysight.com/artifactory/generic-virtual-athena/certificates/Keysight_Root.crt \
    && sudo cp Keysight_Root.crt /usr/local/share/ca-certificates/Keysight_Root.crt \
    && sudo update-ca-certificates
    result=$?
    rm -rf Keysight_Root.crt
    [ ${result} -eq 0 ] || err_exit "Could not install Keysight root cert" 1
}


apt_update() {
    if [ "${APT_UPDATE}" = "true" ]
    then
        check_cmd DEBIAN_FRONTEND=noninteractive sudo apt-get update -yq --no-install-recommends \
            || err_exit "apt-get update failed" 1
        APT_UPDATE=false
    fi
}

apt_install() {
    log "Installing $* ..."
    apt_update \
    && check_cmd DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq --no-install-recommends "$@" \
    && log "Successfully installed $*"
}

apt_install_curl() {
    check_cmd curl --version && return
    apt_install curl
}

apt_install_vim() {
    check_cmd dpkg -s vim && return
    apt_install vim
}

apt_install_git() {
    check_cmd git version && return
    apt_install git
}

apt_install_gnupg() {
    check_cmd gpg -k && return
    apt_install gnupg
}

apt_install_ca_certs() {
    check_cmd dpkg -s ca-certificates && return
    apt_install ca-certificates
}

apt_install_python_is_python3() {
    check_cmd dpkg -s python-is-python3 && return
    apt_install python-is-python3
}

apt_install_python3_pip() {
    check_cmd dpkg -s python3-pip && return
    apt_install python3-pip
}

apt_install_build_essential() {
    check_cmd dpkg -s build-essential && return
    apt_install build-essential
}

apt_install_libpcap_dev() {
    check_cmd dpkg -s libpcap-dev && return
    apt_install libpcap-dev
}

apt_install_jq() {
    check_cmd dpkg -s jq && return
    apt_install jq
}

apt_install_sshpass() {
    check_cmd sshpass -V && return
    apt_install sshpass
}

apt_install_npm() {
    check_cmd dpkg -s npm && return
    apt_install npm
}

apt_install_docker_compose() {
    check_cmd dpkg -s docker-compose-plugin && return
    apt_install docker-compose-plugin
}
npm_install() {
    log "Installing $* ..."
    check_cmd DEBIAN_FRONTEND=noninteractive sudo npm install -g "$@" \
    && log "Successfully installed $*"
}

npm_install_json() {
    check_cmd which json && return
    npm_install json
}

apt_install_pkgs() {
    apt_install_curl \
    && apt_install_vim \
    && apt_install_git \
    && apt_install_gnupg \
    && apt_install_ca_certs \
    && apt_install_jq \
    && apt_install_python_is_python3 \
    && apt_install_python3_pip \
    && apt_install_build_essential \
    && apt_install_libpcap_dev \
    && apt_install_sshpass \
    && apt_install_npm \
    && npm_install_json
}

check_docker_release() {
    log "Checking docker installation ..."
    check_cmd which docker || return 1
    log "Checking docker release ..."
    docker -v | grep " ${1}," || return 1
}

rm_docker() {
    log "Removing any existing docker installation ..."
    check_cmd sudo apt-get remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo rm -rf /etc/apt/sources.list.d/docker.list
    sudo rm -rf /etc/apt/keyrings/docker.gpg
}

get_os_info() {
    . /etc/os-release
    echo "$ID:$VERSION_CODENAME"
}

resolve_docker_version() {
    local os
    os=$(get_os_info)

    case "$os" in
        ubuntu:jammy)
            echo "23.0.5"
            ;;
        ubuntu:noble)
            echo "24.0.9"
            ;;
        debian:bullseye)
            echo "23.0.5"
            ;;
        debian:bookworm)
            echo "24.0.9"
            ;;
        ubuntu:resolute)
            echo "29.8.0"
            ;;
        *)
            echo "latest"
            ;;
    esac
}

resolve_docker_repo_codename() {
    # Probes whether docker's apt repo (DOCKER_REPO_URL, set by the caller
    # per OS family) actually publishes the running codename yet -- new
    # Ubuntu/Debian releases often lag docker.com by months -- and falls
    # back to a long-lived codename known to work, so a brand new codename
    # doesn't need a script edit to install docker correctly.
    local os_codename fallback probe_codename
    . /etc/os-release
    os_codename="${VERSION_CODENAME}"

    case "$ID" in
        debian)
            fallback="bookworm"
            ;;
        *)
            fallback="jammy"
            ;;
    esac

    for probe_codename in "${os_codename}" "${fallback}"
    do
        if curl -ksfL --connect-timeout 2 --max-time 4 -o /dev/null \
            "${DOCKER_REPO_URL}/dists/${probe_codename}/Release"
        then
            echo "${probe_codename}"
            return
        fi
    done

    wrn "Docker apt repo has neither '${os_codename}' nor fallback '${fallback}' -- using '${os_codename}' anyway, install may fail" >&2
    echo "${os_codename}"
}

setup_docker() {
    check_docker_release $(resolve_docker_version) && return
    rm_docker

    log "Installing docker $(resolve_docker_version) ..."

    # Detect OS family
    . /etc/os-release
    case "$ID" in
        debian)
            DOCKER_REPO_URL="https://download.docker.com/linux/debian"
            ;;
        ubuntu)
            DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
            ;;
        *)
            err "Unsupported OS: $ID. Only Debian/Ubuntu are supported."
            return 1
            ;;
    esac

    # Prepare keyring directory
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL ${DOCKER_REPO_URL}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the Docker repo for the detected OS and codename
        docker_arch=$(resolve_docker_arch) || return 1
    echo \
            "deb [arch=${docker_arch} signed-by=/etc/apt/keyrings/docker.gpg] \
      ${DOCKER_REPO_URL} $(resolve_docker_repo_codename) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    log "Checking whether intended version is available for install ..."
    APT_UPDATE=true
    apt_update

    version=$(apt-cache madison docker-ce | awk '{ print $3 }' | grep $(resolve_docker_version))
    if [ -z "$version" ]; then
        err "Docker version $(resolve_docker_version) not found in repository for ${ID} (${VERSION_CODENAME})!"
        return 1
    fi

    log "Found ${version}"
    wrn "Please execute 'systemctl restart docker' if docker service cannot be reached post installation!"
    apt_install docker-ce=${version} docker-ce-cli=${version} containerd.io docker-buildx-plugin docker-compose-plugin
}

sudo_docker() {
    if docker version > /dev/null 2>&1; then
        log "Docker is already accessible without elevated permissions"
        return 0
    fi

    if ! getent group docker > /dev/null 2>&1; then
        sudo groupadd docker
    fi

    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        sudo usermod -aG docker "$USER"
    fi

    sudo docker version > /dev/null 2>&1
    wrn "Docker permissions were updated for ${USER}. Please log out and back in, then re-run the command so the new group membership takes effect."
    exit 0
}

get_docker() {
    log "Getting docker ..."
    setup_docker \
    && sudo_docker
}


common_install() {
    apt_install_pkgs || return 1
    install_keysight_certs || return 1
    get_go || return 1
    get_yq || return 1
    get_docker || return 1

    apt_install_docker_compose || return 1
    install_kubectl || return 1
}

login_ghcr() {
    daemon_json='{
    "insecure-registries" : [ "ghcr.io" ]
}'
    # Only rewrite daemon.json and restart docker if it actually changed --
    # this runs once per topology in run_fp_regression()'s loop, and
    # restarting docker bounces every pod in the kind cluster, which was
    # racing kne's 30s wait for the IxiaTG CRD to go INITIATED.
    if ! echo "${daemon_json}" | diff -q - /etc/docker/daemon.json > /dev/null 2>&1; then
        rm -rf daemon.json
        echo "${daemon_json}" >> daemon.json
        sudo cp daemon.json /etc/docker/daemon.json
        sudo systemctl restart docker
        rm -rf daemon.json
        log "Updated /etc/docker/daemon.json and restarted docker ..."
    else
        log "daemon.json already configured for ghcr.io insecure-registries, skipping docker restart ..."
    fi

    log "Not logged into ghcr.io, attempting login ..."
    if [ -z "$(authq .opts.github-user)" ] || [ -z "$(authq .opts.github-pat)" ]
    then
        wrn "Need to manually log into ghcr.io (Please provide Github Username and PAT)"
        if docker login ghcr.io
        then
            log "Successfully logged into ghcr.io !"
        else
            # non-critical: don't block cluster setup on this -- pulls of
            # public/already-cached images still work without it
            warn_noncritical "Could not log into ghcr.io (manual login) -- pulls of private ghcr.io images may fail later"
        fi
    else
        log "Logging into ghcr.io using credentials provided in auth.yaml"
        if echo "$(authq .opts.github-pat)" | docker login -u"$(authq .opts.github-user)" --password-stdin ghcr.io
        then
            log "Successfully logged into ghcr.io !"
        else
            warn_noncritical "Could not log into ghcr.io using auth.yaml credentials -- pulls of private ghcr.io images may fail later"
        fi
    fi
}

logout_ghcr() {
    log "Logging out of ghcr.io ..."
    docker logout ghcr.io
}

wait_for_sock() {
    start=$(get_seconds)
    timeout=$(configq .timeouts.sock-ready)
    if [ ! -z "${3}" ]
    then
        timeout=${3}
    fi
    log "Waiting for ${1}:${2} to be ready (timeout=${timeout}s)..."
    while true
    do
        check_cmd nc -z -v ${1} ${2} && break

        elapsed=$(( $(get_seconds) - start ))
        if [ $elapsed -gt ${timeout} ]
        then
            err_exit "${1}:${2} not ready after ${timeout}s" 1
        fi
        sleep 0.1
    done

    elapsed=$(( $(get_seconds) - start ))
    log "${1}:${2} ready after ${elapsed}s"
}



check_yq_release() {
    log "Checking yq installation ..."
    check_cmd which yq || return 1
    log "Checking yq release ..."
    yq --version | grep " ${1}$" || return 1
}

rm_yq() {
    log "Removing any existing yq installation ..."
    check_cmd sudo apt-get remove -y yq
    sudo rm -rf $(which yq)
}

get_yq() {
    log "Getting yq ..."

    check_yq_release ${YQ_RELEASE} && return
    rm_yq
    
    log "Installing yq ${YQ_SOURCE} ..."
    go install "${YQ_SOURCE}" && check_yq_release ${YQ_RELEASE}
    log "Successfully installed yq !"
}

check_go_release() {
    log "Checking Go installation ..."
    check_cmd which go || return 1
    log "Checking Go release ..."
    go version | grep " go${1} " || return 1
}

rm_go() {
    log "Removing any existing Go installation ..."
    sudo rm -rvf $(go env 2> /dev/null | grep GOPATH | cut -d\" -f2)
    sudo rm -rvf $(go env 2> /dev/null | grep GOCACHE | cut -d\" -f2)
    check_cmd sudo apt-get remove -y go
    sudo rm -rvf $(which go)
    sudo rm -rvf /usr/local/go
}

get_go() {
    go_version_major=$( go version | awk '{print $3}' | sed 's/go//' | cut -d '.' -f 1)
    go_version_minor=$( go version | awk '{print $3}' | sed 's/go//' | cut -d '.' -f 2)
    if [[ ( "$go_version_major" -gt 1 ) || ( "$go_version_major" -eq 1 && "$go_version_minor" -ge 23 ) ]]; then
        echo "You have updated go version(>= 1.23), hence skipping installation"
        return
    fi
    log "Getting Go ..."

    check_go_release ${GO_RELEASE} && return
    rm_go
    
    log "Installing Go ${GO_RELEASE} ..."
    local go_source
    go_source="$(resolve_go_source)"
    # install golang per https://golang.org/doc/install#tarball
    curl -kL "${go_source}" | sudo tar -C /usr/local/ -xzf - \
    && echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ${DOT_PROFILE} \
    && . ${DOT_PROFILE} \
    && log "Successfully installed Go (please logout and re-login to use go binary) !"
}

get_k9s() {
    [ "$(configq .opts.get-k9s)" != "true" ] && log "Skipping k9s installation" && return
    log "Getting k9s ..."
    rel=$(configq .releases.k9s)
    src="$(configq .sources.k9s)@${rel}"
    check_k9s_release ${rel} && return
    rm_k9s

    log "Installing k9s ${src} ..."
    # if this pinned release's go.mod needs a newer Go than GO_RELEASE,
    # GOTOOLCHAIN=auto silently downloads an extra toolchain to build it
    # (doesn't touch the GO_RELEASE install itself) -- needs proxy.golang.org
    # reachable; get_kind() below has the same exposure via `go install`.
    go install "${src}" && check_k9s_release ${rel}
    log "Successfully installed k9s !"
}

install_kubectl() {
    # --client: this only checks the binary is present, no cluster exists
    # yet at this point in common_install() -- a bare `kubectl version`
    # would also try (and fail) to reach a server, printing a harmless but
    # confusing "connection refused" error
    if kubectl version --client | grep -q "Client Version"; then
        echo "Kubectl already present..."
        return
    else
        local kubectl_release
        kubectl_release="$(configq .releases.kubectl)"
        echo "Kubectl not found..."
        echo "Installing kubectl..."
        sudo apt-get update \
        && sudo apt-get install -y apt-transport-https ca-certificates \
        && curl -fsSL https://pkgs.k8s.io/core:/stable:/${kubectl_release}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
        && sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${kubectl_release}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
        sudo apt-get update
        sudo apt-get install -y kubectl
    fi
}

rm_k9s() {
    log "Removing any existing k9s installation ..."
    sudo rm -rf $(which k9s)
}

check_k9s_release() {
    log "Checking k9s installation ..."
    check_cmd which k9s || return 1
    log "Checking k9s release ..."
    # `k9s version` always prints "Version: dev" for go-install-built
    # binaries (its version ldflags are only set by its own release
    # pipeline, not by `go install`) -- the real pinned version is still
    # embedded in Go's module build info, so read it from there instead.
    go version -m "$(which k9s)" | awk -v mod="$(configq .sources.k9s)" -v want="${1}" \
        '$1 == "mod" && $2 == mod && $3 == want { found = 1 } END { exit !found }' \
        || return 1
}

get_kind() {
    log "Getting kind ..."
    # $1 = version to install -- only caller is install_kind_for_kne_bridge(),
    # which resolves this from kne's own kind-bridge.yaml
    rel="${1}"
    src="$(configq .sources.kind)@${rel}"

    check_kind_release ${rel} && return
    rm_kind
    
    log "Installing kind ${src} ..."
    go install "${src}" && check_kind_release ${rel}
    log "Successfully installed kind !"
}

check_kind_release() {
    log "Checking kind installation ..."
    check_cmd which kind || return 1
    log "Checking kind release ..."
    kind version | grep " ${1} " || return 1
}

rm_kind() {
    rm_kind_clusters
    log "Removing any existing kind installation ..."
    sudo rm -rf $(which kind)
}

rm_kind_clusters() {
    log "Removing any existing kind cluster ..."
    check_cmd kind delete cluster
    rm -rf "${DOT_KUBE}"
}

kind_install_certs() {
    log "Checking if cert installation is needed on kind nodes"
    case "$(configq .opts.kind-certs)" in
        false )
            log "kind-certs is set to 'false', skipping cert installation on kind nodes"
            return 0
        ;;
        * )
            log "kind-certs is set to 'auto', probing TLS trust on each kind node ..."
            for node in $(kubectl get nodes -o=jsonpath='{.items[*].metadata.name}')
            do
                log "Probing TLS trust to ghcr.io from node ${node} ..."
                if docker exec ${node} sh -c "curl -sS -o /dev/null -w '%{http_code}' https://ghcr.io/token" > /dev/null 2>&1
                then
                    log "Node ${node} already trusts required certs, skipping installation."
                else
                    log "Node ${node} does not trust required certs, install certs! ..."
                fi
            done
            log "Finished checking/installing certs on all kind nodes !"
        ;;
    esac
}

kind_setup_auth() {
    [ "$(configq .opts.kind-auth)" != "true" ] && log "Skipping ghcr.io & artifatory-lbj authentication for kind cluster" && return
    log "Setting up ghcr.io & artifatory-lbj authentication for kind cluster ..."
    login_ghcr \
    && cp ${DOCKER_CONFIG} $(configq .paths.docker-config) \
    && log "Successfully setup ghcr.io & artifatory-lbj authentication for kind cluster !"
}

setup_kind_auth() {
    log "Moving credentials to kind cluster name=\'kind\' nodes ..."
    node=$(kind get nodes --name kind)
    # skip restart if kubelet's config.json already matches (see
    # kind_install_certs() for why checksum, not `cmp`)
    want_sum=$(sha256sum "$HOME/.docker/config.json" | awk '{print $1}')
    have_sum=$(docker exec $node sha256sum /var/lib/kubelet/config.json 2>/dev/null | awk '{print $1}')
    if [ -n "${have_sum}" ] && [ "${want_sum}" = "${have_sum}" ]
    then
        log "kubelet config.json already up to date on node ${node}, skipping restart"
        return 0
    fi
    docker cp "$HOME/.docker/config.json" "$node:/var/lib/kubelet/config.json" \
    && docker exec $node systemctl restart kubelet.service \
    || err_exit "Could not update kubelet credentials on node ${node}" 1
}

get_kne_src() {
    # skip re-clone/rebuild if already at the desired ref. releases.kne-src
    # (optional) pins this flow to a tag/commit; unset means keep tracking
    # `main` as before.
    local rel local_rev target_rev
    rel="$(configq .releases.kne-src)"
    [ "${rel}" = "null" ] && rel=""

    if [ -d kne/.git ] && which kne > /dev/null 2>&1
    then
        local_rev="$(git -C kne rev-parse HEAD 2>/dev/null)"
        if [ -n "${rel}" ]
        then
            # pinned: a tag/commit's SHA never moves, so no need to fetch
            # to check for drift -- just see if we're already there
            target_rev="$(git -C kne rev-parse "${rel}" 2>/dev/null)"
        else
            # tracking main: only a fetch can tell us if upstream moved
            target_rev="$(git -C kne fetch --quiet origin main && git -C kne rev-parse origin/main 2>/dev/null)"
        fi
        if [ -n "${target_rev}" ] && [ "${local_rev}" = "${target_rev}" ]
        then
            log "kne already at desired ref (${local_rev}), skipping re-clone/rebuild"
            return 0
        fi
    fi

    log "removing any existing kne"
    rm -rf kne
    log "Cloning kne"
    git clone https://github.com/openconfig/kne.git \
        || err_exit "Could not clone kne from https://github.com/openconfig/kne.git" 1
    if [ -n "${rel}" ]
    then
        log "Pinning kne to ${rel} (config.yaml releases.kne-src)"
        (cd kne && git checkout "${rel}") || err_exit "kne ref '${rel}' (config.yaml releases.kne-src) not found" 1
    fi
    log "Installing kne"
    cd kne && make install && cd -
}

resolve_kind_version_from_kne() {
    # reads the kind version kne's own kind-bridge.yaml requires -- this is
    # the only source of truth for which kind version to install
    yq '.cluster.spec.version' kne/deploy/kne/kind-bridge.yaml 2>/dev/null
}

install_kind_for_kne_bridge() {
    local rel
    rel="$(resolve_kind_version_from_kne)"
    # no config.yaml fallback: if this is unreadable, modify_kind_bridge_yaml()
    # and deploy_kind() -- which read the same file moments later in this same
    # chain -- would fail too, so a fallback here would just install some kind
    # version and then fail anyway a step later, with a more confusing error
    [ -n "${rel}" ] && [ "${rel}" != "null" ] \
        || err_exit "Could not read required kind version from kne/deploy/kne/kind-bridge.yaml" 1
    get_kind "${rel}"
}

# report-only -- metallb/meshnet versions here come from kne's own bundled
# manifests, not config.yaml's releases.metallb/releases.meshnet (this flow
# doesn't use those; kne deploy installs whatever it bundled for its ref)
report_kne_bundle_versions() {
    local metallb_img meshnet_img
    metallb_img="$(grep -m1 'controller:v' kne/manifests/metallb/manifest.yaml 2>/dev/null | awk '{print $2}')"
    meshnet_img="$(grep -m1 '^\s*image:' kne/manifests/meshnet/grpc/manifest.yaml 2>/dev/null | awk '{print $2}')"
    log "This kne ref will deploy metallb (${metallb_img:-unknown}) and meshnet (${meshnet_img:-unknown}) per its own bundled manifests -- config.yaml's releases.metallb/releases.meshnet do not apply to this flow (see comment above)"
}

modify_kind_bridge_yaml() {
    log "Rename the kind bridge as kind"
    cd kne \
    && yq -i '.cluster.spec.name = "kind"' deploy/kne/kind-bridge.yaml \
    && yq -i '.containerdConfigPatches = ["[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"ghcr.io\"]\n  endpoint = [\"https://ghcr.io\"]\n[plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"ghcr.io\".tls]\n  insecure_skip_verify = true"]' manifests/kind/config.yaml \
    && cd -
}

deploy_kind() {
    kne deploy -v 3 kne/deploy/kne/kind-bridge.yaml
}

kind_new_cluster_from_bridge() {
    # kind is installed here, after kne is cloned/pinned, using the version
    # kne itself requires (install_kind_for_kne_bridge())
    get_kne_src \
    && install_kind_for_kne_bridge \
    && report_kne_bundle_versions \
    && modify_kind_bridge_yaml \
    && deploy_kind
}

remove_kne() {
    log "Removing kne folder..."
    rm -rf kne
}

setup_kind_from_bridge() {
    log "Setting up kind cluster ..."
    # kind install moved to kind_new_cluster_from_bridge() -- it needs kne
    # checked out first
    get_k9s \
    && kind_setup_auth \
    && kind_new_cluster_from_bridge \
    && setup_kind_auth \
    && kind_install_certs \
    && log "Successfully setup kind cluster !" \
    && remove_kne
}

load_cisco_kind() {
    log "loading image to kind"
    kind load docker-image $(configq .images.cisco.path):$(configq .images.cisco.tag)
}

get_cisco_image() {
   log "pulling image from google cloud"
   sudo sysctl kernel.pid_max=1048575
   docker pull $(configq .images.cisco.path):$(configq .images.cisco.tag) \
   && load_cisco_kind
}

get_keng_operator_manifest() {
    local remote_manifest local_manifest resolved_manifest
    remote_manifest="$(configq .sources.keng-operator)"
    local_manifest="deployments/k8s/ixiatg-operator.yaml"

    log "Checking keng-operator manifest availability at ${remote_manifest} ..." >&2
    if curl -kfsSLI --connect-timeout 10 --max-time 30 "${remote_manifest}" > /dev/null 2>&1
    then
        log "Using online keng-operator manifest ${remote_manifest}" >&2
        echo "${remote_manifest}"
        return 0
    fi

    wrn "Online keng-operator manifest unavailable, falling back to local ${local_manifest}" >&2
    [ -f "${local_manifest}" ] || err_exit "Local keng-operator manifest not found: ${local_manifest}" 1

    resolved_manifest="$(eval_yaml "${local_manifest}")"
    log "Using evaluated local keng-operator manifest ${resolved_manifest}" >&2
    echo "${resolved_manifest}"
}

rm_keng_operator() {
    local manifest
    manifest="$(get_keng_operator_manifest)" || return 1

    log "Removing keng-operator ${manifest} ..."
    kubectl delete -f "${manifest}" \
    && wait_for_no_namespace ixiatg-op-system \
    && log "Successfully removed keng-operator !"
}

rm_arista_ceos_operator() {
    local source

    source="$(configq .sources.arista-ceos-operator)"

    log "Removing arista ceos operator $(configq .images.arista-ceos-operator.tag) ..."

    if ! kubectl kustomize "${source}" \
        | sed \
            's#gcr.io/kubebuilder/kube-rbac-proxy:v0.11.0#quay.io/brancz/kube-rbac-proxy:v0.11.0#g' \
        | kubectl delete -f - --ignore-not-found=true; then
        log "Failed to remove arista ceos operator!"
        return 1
    fi

    wait_for_no_namespace arista-ceoslab-operator-system \
        || {
            log "Timed out waiting for arista-ceoslab-operator-system namespace removal!"
            return 1
        }

    log "Successfully removed arista ceos operator!"
}

get_kubemod() {
    return
    kubectl label namespace kube-system admission.kubemod.io/ignore=true --overwrite \
    && kubectl apply -f https://raw.githubusercontent.com/kubemod/kubemod/v0.15.3/bundle.yaml \
    && wait_for_pods kubemod-system
}

wait_for_pods() {
    log "Waiting for pods ...."
    for n in $(kubectl get namespaces -o 'jsonpath={.items[*].metadata.name}')
    do
        if [ ! -z "$1" ] && [ "$1" != "$n" ]
        then
            continue
        fi
        for p in $(kubectl get pods -n ${n} -o 'jsonpath={.items[*].metadata.name}')
        do
            if [ ! -z "$2" ] && [ "$2" != "$p" ]
            then
                continue
            fi
            log "Waiting for pod/${p} in namespace ${n} (timeout=$(configq .timeouts.pod-ready)s)..."
            kubectl wait -n ${n} pod/${p} --for condition=ready --timeout=$(configq .timeouts.pod-ready)s || return 1
        done
    done
    log "Done waiting for pods"

    kubectl get pods -A -o wide
}

wait_for_services() {
    log "Waiting for services ...."
    for n in $(kubectl get namespaces -o 'jsonpath={.items[*].metadata.name}')
    do
        if [ ! -z "$1" ] && [ "$1" != "$n" ]
        then
            continue
        fi
        for s in $(kubectl get services -n ${n} -o 'jsonpath={.items[*].metadata.name}')
        do
            if [ ! -z "$2" ] && [ "$2" != "$s" ]
            then
                continue
            fi

            h=$(get_external_ip ${n} ${s})
            if [ -z "${h}" ]
            then
                log "Service/${s} in namespace ${n} has not yet received an external IP; retrying until MetalLB assigns one..."
                for _ in $(seq 1 30)
                do
                    h=$(get_external_ip ${n} ${s})
                    [ -n "${h}" ] && break
                    sleep 2
                done
            fi
            if [ -z "${h}" ]
            then
                err_exit "Service/${s} in namespace ${n} never received an external IP" 1
            fi

            log "Waiting for service/${s} in namespace ${n} with external IP ${h} ..."
            i=0
            for p in $(kubectl get service ${s} -n ${n} -o 'jsonpath={.spec.ports[*].port}')
            do
                name=$(kubectl get service ${s} -n ${n} -o "jsonpath={.spec.ports[${i}].name}")
                case "$name" in 
                *ssl*)
                    continue
                    ;;
                esac
                log "Waiting for TCP port ${p} ..."
                wait_for_sock ${h} ${p} || return 1
                i=$((i + 1))
            done
        done
    done
    log "Done waiting for services !"

    kubectl get services -A -o wide
}

wait_for_no_namespace() {
    start=$(get_seconds)
    inf "Waiting for namespace ${1} to be deleted (timeout=$(configq .timeouts.namespace-cleanup)s)..."
    while true
    do
        found=""
        for n in $(kubectl get namespaces -o 'jsonpath={.items[*].metadata.name}')
        do
            if [ "$1" = "$n" ]
            then
                found="$n"
                break
            fi
        done

        if [ -z "$found" ]
        then
            return 0
        fi

        elapsed=$(( $(get_seconds) - start ))
        if [ $elapsed -gt $(configq .timeouts.namespace-cleanup) ]
        then
            err_exit "Namespace ${1} not deleted after $(configq .timeouts.namespace-cleanup)s" 1
        fi
    done
    log "Done waiting for namespace to be deleted !"

    kubectl get pods -A -o wide
    kubectl get services -A -o wide
}

get_running_pods_count() {
    count=0
    podStatus=$(kubectl get pods -n $1 -o=jsonpath='{range .items[*]}{.status.conditions[?(@.type=="ContainersReady")].status}{"\n"}{end}')
    for elem in $podStatus
    do
        if [ "$elem" = "True" ]
        then
            count=$((count+1))
        fi
    done
    echo $count
}

get_namespace_status() {
    kubectl get namespaces $1 -o 'jsonpath={.status.phase}'
}

check_name_space_exists() {
    kubectl get namespace "$1" --no-headers 2> /dev/null | wc -l
}

check_namespce_health() {
    if [ $(get_namespace_status $1) = "Active" ]
    then
        if [ -z $2 ]
        then
            echo "ok"
        else 
            if [ $(get_running_pods_count $1) = $2 ]
            then
                echo "ok"
            else
                echo "not-ok"
            fi
        fi
    else
        echo "not-ok"
    fi 
}

# fixed two typos that made the unhealthy-cluster path unreachable: a
# missing space before `]` in two of the `[ ... ]` checks below (always
# failed with "binary operator expected"), and a call to the undefined
# `rm_kne_cluster` instead of `rm_kind_clusters`.
check_kind_bridge_cluster_health() {
    health="not-ok"
    if [ $(check_namespce_health kube-system 8) = "ok"  ]
    then
        if [ $(check_namespce_health meshnet 1) = "ok"  ]
        then
            if [ $(check_namespce_health metallb-system 2) = "ok"  ]
            then
                if [ $(check_namespce_health local-path-storage 1) = "ok"  ]
                then
                    if [ $(check_namespce_health arista-ceoslab-operator-system 1) = "ok"  ]
                    then
                        if [ $(check_namespce_health ixiatg-op-system 1) = "ok" ]
                        then
                            if [ $(check_namespce_health lemming-operator 1) = "ok" ]
                            then
                                if [ $(check_namespce_health srlinux-controller 1) = "ok" ]
                                then
                                    if [ $(check_name_space_exists ixia-c) = 0 ]
                                    then
                                        if [ $(check_name_space_exists ixia-c-alt) = 0 ]
                                        then
                                            health="ok"
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
    if [ $health = "not-ok" ]
    then
        echo "Cluster health is not ok, so re-deploying the cluster...."
        rm_kind_clusters \
        && setup_kind_from_bridge
    else
        echo "Cluster is ok..."
    fi
}


load_image_to_kind() {
    docker pull "${1}" \
    && kind load docker-image "${1}" --name kind
}

preload_images() {
    log "Preloading images for which preload=true ..."
    for name in $(yq ".images | keys" ${CONFIG_YAML})
    do
        if [ "${name}" != "-" ]
        then
            preload=$(configq .images[\"${name}\"].preload)
            if [ "${preload}" = "true" ]
            then
                img=$(configq .images[\"${name}\"].path):$(configq .images[\"${name}\"].tag)
                log "Preloading ${img} ..."
                load_image_to_kind "${img}" || return 1
            fi
        fi
    done
    log "Successfully preloaded images !"
}

# Reports whether newer upstream releases exist for the versions pinned in
# config.yaml. Best-effort and non-blocking: each lookup runs in parallel
# with a short timeout, so an unreachable network adds ~4-5s total, not
# per-check, and a failed lookup is just reported as "unknown". Opt out via
# `opts.check-latest-versions: false` in config.yaml.
_gh_latest_tag() {
    # $1 = "owner/repo" -> latest release tag_name on stdout, empty on
    # failure/timeout/rate-limit
    curl -ksf --connect-timeout 2 --max-time 4 \
        "https://api.github.com/repos/${1}/releases/latest" 2>/dev/null \
        | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

_git_latest_commit() {
    # $1 = repo url, $2 = branch -> short SHA of branch HEAD on stdout
    git ls-remote --exit-code "${1}" "${2}" 2>/dev/null | awk '{print substr($1,1,7)}'
}

_report_version_status() {
    # $1 = label, $2 = pinned value, $3 = file with the latest fetched value
    # (may be empty/missing). Prints one aligned table row, no timestamps.
    local latest
    latest=$(cat "${3}" 2>/dev/null)
    if [ -z "${latest}" ]; then
        printf "%-14s %-16s %-16s\n" "${1}" "${2}" "unknown"
        return 0
    fi
    if [ "${latest#v}" != "${2#v}" ]; then
        printf "%-14s %-16s %-16s\n" "${1}" "${2}" "${latest}"
    else
        printf "%-14s %-16s %-16s\n" "${1}" "${2}" "latest"
    fi
}

check_latest_versions() {
    # default enabled -- skip only if explicitly set to false
    [ "$(configq .opts.check-latest-versions)" != "false" ] || { log "check-latest-versions disabled in config.yaml, skipping"; return 0; }

    local tmp
    tmp=$(mktemp -d) || { log "Could not create temp dir for version check, skipping"; return 0; }

    ( _gh_latest_tag derailed/k9s          > "${tmp}/k9s" )          &
    ( _gh_latest_tag srl-labs/containerlab > "${tmp}/containerlab" ) &
    ( _gh_latest_tag openconfig/kne        > "${tmp}/kne" )          &
    ( _gh_latest_tag mikefarah/yq          > "${tmp}/yq" )          &
    ( curl -ksf --connect-timeout 2 --max-time 4 https://go.dev/VERSION?m=text 2>/dev/null | head -1 > "${tmp}/go" ) &
    ( curl -ksf --connect-timeout 2 --max-time 4 https://dl.k8s.io/release/stable.txt 2>/dev/null > "${tmp}/kubectl_full" ) &
    wait

    [ -s "${tmp}/kubectl_full" ] && cut -d. -f1,2 "${tmp}/kubectl_full" > "${tmp}/kubectl"

    printf "%-14s %-16s %-16s\n" "COMPONENT" "CURRENT" "LATEST"
    _report_version_status "k9s" "$(configq .releases.k9s)" "${tmp}/k9s"
    _report_version_status "containerlab" "$(configq .releases.containerlab)" "${tmp}/containerlab"
    kne_src_pin="$(configq .releases.kne-src)"
    if [ -n "${kne_src_pin}" ] && [ "${kne_src_pin}" != "null" ]
    then
        # kne-src: setup()'s bridge-flow pin
        _report_version_status "kne-src" "${kne_src_pin}" "${tmp}/kne"
    else
        printf "%-14s %-16s %-16s\n" "kne-src" "unset" "tracks main"
    fi
    # go/yq: GO_RELEASE/YQ_RELEASE, hardcoded -- config.yaml can't be read
    # (via yq) until get_go()/get_yq() have already run, see their
    # declaration comment above for why these two stay shell constants
    _report_version_status "go" "${GO_RELEASE}" "${tmp}/go"
    _report_version_status "yq" "${YQ_RELEASE}" "${tmp}/yq"
    _report_version_status "kubectl" "$(configq .releases.kubectl)" "${tmp}/kubectl"

    rm -rf "${tmp}"
}

setup() {
    inf "Setting up ixops ..."
    common_install \
    && setup_kind_from_bridge \
    && log "Successfully set up ixops !"
    check_latest_versions
}

cleanup() {
    rm_kind_clusters \
    && rm_go
    check_latest_versions
}

eval_yaml() {
    new_yaml=$(dirname ${1})/.$(basename ${1})
    rm -rf ${new_yaml}

    # avoid splitting based on whitespace
    IFS=''
    # mix of cat and echo is used to ensure the input file has
    # at least one newline before EOF, otherwise read will not
    # provide last line
    { cat ${1}; echo; } | while read line; do
        # replace all double-quotes with single quotes
        line=$(echo "${line}" | sed s#\"#\'#g)
        # and revert them back to double-quotes post eval;
        # this will result in converting all single-quotes
        # to double-quotes regardless of whether they were
        # originally double-quotes, but hopefully this won't
        # be an issue
        # this workaround was put in place because eval gets
        # rid of double-quotes
        eval echo \"$line\" | sed s#\'#\"#g >> ${new_yaml}
    done
    # restore default IFS
    unset IFS
    echo ${new_yaml}
}

get_lic_servers() {
    servers=""
    for val in $(configq .license-servers.${1})
    do
        if [ "${val}" != "-" ]
        then
            servers="$servers $val"
        fi
    done
    echo $servers
}

create_license_server_secret() {
    if [ ${1} = "container-kne" ]
    then 
        kubectl create secret -n ixiatg-op-system generic license-server --from-literal=image="$(configq .images.keng-license-server.path):$(configq .images.keng-license-server.tag)"
        log "Successfully created license-server secret..."
    else
        if [ ${1} = "legacy" ]
        then 
            log "license-server secret is not created because legacy build is used!!"
        else 
            kubectl create secret -n ixiatg-op-system generic license-server --from-literal=addresses="$(get_lic_servers $1)"
            log "Successfully created license-server secret..."
        fi
    fi
}

apply_ixia_c_config() {
    cfg=$(configq .paths.ixia-c-config)
    if [ ${1} = "legacy" ]
    then 
        cfg=$(configq .paths.ixia-c-config-legacy)
    fi
    log "Applying ixia-c config ${cfg}"
    log "Getting evaluated YAML ..."
    yml=$(eval_yaml ${cfg})
    log "Using ${yml} to apply ..."
    cat ${yml}
    kubectl apply -f ${yml} \
    && log "Successfully applied ixia-c config"
}

build_topology_file() {
    topo_file_path=$(dirname $1)/topology.txt
    dot_topo_path=$(dirname $1)/.topology.txt
    cat $topo_file_path > $dot_topo_path
    if [ $2 = "nokia" ];then
        image=$(configq .images.srlinux.path)
        tag=$(configq .images.srlinux.tag)
    elif [ $2 = "arista" ]; then
        image=$(configq .images.arista-ceos.path)
        tag=$(configq .images.arista-ceos.tag)
    else
        image=$(configq .images.$2.path)
        tag=$(configq .images.$2.tag)
    fi
    image_path="$image:$tag"
    sed -i "s|image: \".*:DUTVERSION\"|image: \"$image_path\"|g" "$dot_topo_path"
}

deploy_topology() {
    echo "deploying topology: $1"
    kne create -v 3 $1
    echo "===================== created topo using txt ==================="
    wait_for_pods ixia-c
    wait_for_services ixia-c 2> /dev/null || true
    echo "$1 topology deployed successfully"
}

new_kne_topo() {
    # $1-> path $2-> LS, $3-> dut
    inf "Creating KNE topology ${1} ..."
    kind_setup_auth || err_exit "Could not set up kind cluster auth" 1
    kubectl delete secret -n ixiatg-op-system license-server 2> /dev/null || true
    create_license_server_secret ${2} || return 1
    apply_ixia_c_config ${2} || return 1
    topo_path=$(dirname $1)
    input_file="$1"
    if [ "$3" = "cisco" ]; then
        sudo sysctl kernel.pid_max=1048575
    fi
    if [ "${input_file##*.}" = "txt"  ]
    then 
        echo "==============txt=============="
        build_topology_file $1 $3
        deploy_topology $topo_path/.topology.txt $2
    else      
        echo "=======yaml======="
        if [ -d ${1} ]
        then
            for topo_yaml in ${1}/*.yaml; do
                log "Getting evaluated YAML ..."
                topo=$(eval_yaml ${topo_yaml})
                log "Using ${topo} to create topology ..."
                sleep 5
                cat ${topo}
                ns=$(yq .name ${topo})
                model=$(yq .nodes[].model ${topo})
                for dut in $model; do
                    if [ "$dut" == 8201 ]
                    then
                        get_cisco_image
                    fi    
                done    

                kne create ${topo} \
                && wait_for_pods ${ns} \
                && log "Successfully created topology !" \
                && wait_for_services ${ns}
            done
        else
            log "Getting evaluated YAML ..."
            topo=$(eval_yaml ${1})
            sleep 5
            log "Using ${topo} to create topology ..."
            cat ${topo}
            ns=$(yq .name ${topo})
            kne create ${topo} \
            && wait_for_pods ${ns} \
            && log "Successfully created topology !" \
            && wait_for_services ${ns}
        fi
    fi
}

rm_kne_topo() {
    inf "Deleting KNE topology ${1} ..."
    kubectl delete secret -n ixiatg-op-system license-server 2> /dev/null || true
    topo_path=$(dirname $1)
    input_file="$1"
    if [ "${input_file##*.}" = "txt"  ]
    then 
        echo "==============txt=============="
        kne delete $topo_path/.topology.txt $2
        kubectl delete namespace ixia-c 2> /dev/null || true
        wait_for_no_namespace ixia-c \
        && log "Successfully deleted topology !"
    else
        if [ -d ${1} ]
        then
            for topo_yaml in ${1}/*.yaml; do 
                log "Getting evaluated YAML ..."
                topo=$(eval_yaml ${topo_yaml})
                log "Using ${topo} to delete topology ..."
                cat ${topo}
                ns=$(yq .name ${topo})

                kne delete ${topo}
                kubectl delete namespace $ns 2> /dev/null || true
                wait_for_no_namespace ${ns} \
                && log "Successfully deleted topology !"
            done
        else
            log "Getting evaluated YAML ..."
            topo=$(eval_yaml ${1})
            log "Using ${topo} to delete topology ..."
            cat ${topo}
            ns=$(yq .name ${topo})

            kne delete ${topo}
            kubectl delete namespace $ns 2> /dev/null || true
            wait_for_no_namespace ${ns} \
            && log "Successfully deleted topology !"
        fi
    fi
}

wait_for_docker_compose_services() {
    topo=${1}
    if echo "$topo" | grep -v "keng_licserv"
    then
        # controller docker services
        https_port=8443
        log "Waiting for TCP port ${https_port} ..."
        wait_for_sock localhost ${https_port} || return 1

        grpc_port=40051
        log "Waiting for TCP port ${grpc_port} ..."
        wait_for_sock localhost ${grpc_port} || return 1

        gnmi_port=50051
        log "Waiting for TCP port ${gnmi_port} ..."
        wait_for_sock localhost ${gnmi_port} || return 1
    fi

    if echo "$topo" | grep -q "ixhw_server"
    then 
        # ixhw-server docker services
        ixhw_port=5001
        log "Waiting for TCP port ${ixhw_port} ..."
        wait_for_sock localhost ${ixhw_port} || return 1
    fi
}


new_docker_compose_topo() {
    inf "Removing existing Docker-compose topology ..."
    docker stop -f $(docker ps -a | grep ixia-c | awk '{print $1}') 2> /dev/null || true
    docker rm -f $(docker ps -a | grep ixia-c | awk '{print $1}') 2> /dev/null || true
    inf "Creating Docker-Compose topology ${1} ..."
    login_ghcr
    if [ -d ${1} ]
    then
        for topo_yaml in ${1}/*.yaml; do 
            log "Getting evaluated YAML ..."
            topo=$(eval_yaml ${topo_yaml})
            sleep 5
            log "Using ${topo} to create topology ..."
            if [ -z "${2}" ] 
            then
                cat ${topo}
            else
                cat $topo | \
                    sed "s/LIC_SERVERS/$(get_lic_servers $2)/g" | \
                    tee $topo > /dev/null
                cat ${topo}
            fi
            docker compose -f ${topo} --profile all up -d \
            && wait_for_docker_compose_services ${1}
            log "Successfully created topology !"
        done
    else
        log "Getting evaluated YAML ..."
        topo=$(eval_yaml ${1})
        sleep 5
        log "Using ${topo} to create topology ..."
        if [ -z "${2}" ] 
        then
            cat ${topo}
        else
            cat $topo | \
                sed "s/LIC_SERVERS/$(get_lic_servers $2)/g" | \
                tee $topo > /dev/null
            cat ${topo}
        fi
        docker compose -f ${topo} --profile all up -d \
        && wait_for_docker_compose_services ${1}
        log "Successfully created topology !"
    fi
}

rm_docker_compose_topo() {
    inf "Deleting Docker-Compose topology ${1} ..."
    login_ghcr
    if [ -d ${1} ]
    then
        for topo_yaml in ${1}/*.yaml; do 
            log "Getting evaluated YAML ..."
            topo=$(eval_yaml ${topo_yaml})
            log "Using ${topo} to delete topology ..."
            cat ${topo}
            docker compose -f ${topo} --profile all down
            log "Successfully deleted topology !"
        done
    else
        log "Getting evaluated YAML ..."
        topo=$(eval_yaml ${1})
        log "Using ${topo} to delete topology ..."
        cat ${topo}
        docker compose -f ${topo} --profile all down
        log "Successfully deleted topology !"
    fi
}

new_containerlab_topo() {
    inf "Creating Containerlab topology ${1} ..."
    login_ghcr
    if [ -d ${1} ]
    then
        for topo_yaml in ${1}/*.yaml; do
            log "Getting evaluated YAML ..."
            topo=$(eval_yaml ${topo_yaml})
            sleep 5
            log "Using ${topo} to create topology ..."
            cat ${topo}
            sudo rm -rf clab-$(yq .name ${topo})

            docker stop -f $(docker ps -a | grep clab | awk '{print $1}') 2> /dev/null || true
            docker rm -f $(docker ps -a | grep clab | awk '{print $1}') 2> /dev/null || true
            sudo containerlab deploy --reconfigure --topo  ${topo}
            log "Successfully created topology !"
        done
    else
        log "Getting evaluated YAML ..."
        topo=$(eval_yaml ${1})
        log "Using ${topo} to create topology ..."
        cat ${topo}
        sudo rm -rf clab-$(yq .name ${topo})

        docker stop -f $(docker ps -a | grep clab | awk '{print $1}') 2> /dev/null || true
        docker rm -f $(docker ps -a | grep clab | awk '{print $1}') 2> /dev/null || true
        sudo containerlab deploy --reconfigure --topo  ${topo}
        log "Successfully created topology !"
    fi
}

rm_containerlab_topo() {
    inf "Deleting Containerlab topology ${1} ..."
    login_ghcr
    if [ -d ${1} ]
    then
        for topo_yaml in ${1}/*.yaml; do
            log "Getting evaluated YAML ..."
            topo=$(eval_yaml ${topo_yaml})
            log "Using ${topo} to delete topology ..."
            cat ${topo}
            sudo containerlab destroy --topo ${topo}
            sudo rm -rf clab-$(yq .name ${topo})
            log "Successfully deleted topology !"
        done
    else
        log "Getting evaluated YAML ..."
        topo=$(eval_yaml ${1})
        log "Using ${topo} to delete topology ..."
        cat ${topo}
        sudo containerlab destroy --topo ${topo}
        sudo rm -rf clab-$(yq .name ${topo})
        log "Successfully deleted topology !"
    fi
}


new_docker_ixhw_topo() {
    login_ghcr
    local ixhw_image controller_image
    ixhw_image="$(configq .images.keng-layer23-hw-server.path):$(configq .images.keng-layer23-hw-server.tag)"
    controller_image="$(configq .images.keng-controller.path):$(configq .images.keng-controller.tag)"

    inf "Creating Docker IXHW topology ..."
    docker run -d \
        --name keng-layer23-hw-server \
        --restart always \
        --network host \
        "${ixhw_image}" \
        dotnet otg-ixhw.dll \
        --trace \
        --log-level trace \
        || err_exit "Could not start keng-layer23-hw-server" 1

    docker run -d \
        --name keng-controller \
        --restart always \
        --network host \
        -e GRPC_GO_LOG_VERBOSITY_LEVEL=99 \
        -e GRPC_GO_LOG_SEVERITY_LEVEL=info \
        -e LICENSE_SERVERS=$(get_lic_servers $1) \
        -e SHOW_DEBUG_SPANS=TRUE \
        -e ENABLE_STREAM_WARNINGS=True \
        "${controller_image}" \
        --accept-eula \
        --debug \
        --keng-layer23-hw-server localhost:5001 \
        || err_exit "Could not start keng-controller" 1
    log "Successfully created Docker IXHW topology !"
}

rm_docker_ixhw_topo() {
    inf "Deleting Docker IXHW topology ..."
    docker rm -f keng-controller keng-layer23-hw-server \
        || err_exit "Could not delete Docker IXHW topology" 1
    log "Successfully deleted Docker IXHW topology !"
}


get_external_ip() {
    ns=${1}
    svc=${2}
    kubectl get service ${svc} -n ${ns} -o 'jsonpath={.status.loadBalancer.ingress[0].ip}' 2>/dev/null
}


get_version_yaml() {
    echo "getting version yaml.."
    URL="https://artifactorylbj.it.keysight.com/artifactory/generic-virtual-athena/builds/$1/versions.yaml"

    if curl --output /dev/null --silent --head --fail "$URL"; then
        echo "URL exists"
        curl -kLO $URL
        echo "Downloaded version yaml of controller version $1"
    else
        echo "URL does not exist"
        return
    fi

}

update_keng_version_in_config_yaml() {
    get_version_yaml $1
    if [ ! -f "versions.yaml" ]; then
        err_exit "version yaml Not found, Exiting the execution.." 1
    fi
    yq -i e ".releases.snappi = \"$(configqf .snappi versions.yaml)\"" config.yaml
    yq -i e ".releases.gosnappi = \"$(configqf .gosnappi versions.yaml)\"" config.yaml
    yq -i e ".images.keng-controller.tag = \"$(configqf .keng-controller versions.yaml)\"" config.yaml
    yq -i e ".images.ixia-c-traffic-engine.tag = \"$(configqf .ixia-c-traffic-engine versions.yaml)\"" config.yaml
    yq -i e ".images.ixia-c-protocol-engine.tag = \"$(configqf .ixia-c-protocol-engine versions.yaml)\"" config.yaml
    yq -i e ".images.otg-gnmi-server.tag = \"$(configqf .otg-gnmi-server versions.yaml)\"" config.yaml
    yq -i e ".images.keng-operator.tag = \"$(configqf .keng-operator versions.yaml)\"" config.yaml
    yq -i e ".images.keng-layer23-hw-server.tag = \"$(configqf .keng-layer23-hw-server versions.yaml)\"" config.yaml
    yq -i e ".images.keng-app-usage-reporter.tag = \"$(configqf .keng-app-usage-reporter versions.yaml)\"" config.yaml
    yq -i e ".images.ixia-c-one.tag = \"$(configqf .ixia-c-one versions.yaml)\"" config.yaml
    yq -i e ".images.uhd400.tag = \"$(configqf .uhd400 versions.yaml)\"" config.yaml
}

update_dut_version_in_config_yaml() {
    if [[ "$1" == "arista" ]]; then
        yq -i e ".images.arista-ceos.tag = \"$2\"" config.yaml
    else 
        yq -i e ".images.$1.tag = \"$2\"" config.yaml
    fi
    echo "successfully updated dut version"
}

parse_args() {
    dut_version=""
    controller_version=""
    dut=""
    counter=1;
    for args in "$@"; do
        if [[ $counter == 2 && "$args" =~ ([a-zA-Z]+):([0-9]+).* ]]; then
            dut=$(echo "$args" | cut -d ":" -f 1)
            dut_version=$(echo "$args" | cut -d ":" -f 2)
        elif [[ $counter == 2 && "$args" =~ ([a-zA-Z]+) ]]; then
            dut="$args"
        elif [[ "$args" =~ ([0-9]+).* ]]; then
            controller_version="$args"
        fi
        counter=$(( counter + 1 ))
    done
    if [ -n "$dut_version" ]; then
        update_dut_version_in_config_yaml $dut $dut_version
    fi
    if [ -n "$controller_version" ]; then
        update_keng_version_in_config_yaml $controller_version
    fi
}

remove_version_yaml() {
    if [ -f "versions.yaml" ]; then
        rm -f "versions.yaml"
    fi
}

help() {
    grep "() {" ${0} | cut -d\  -f1
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N')     LOG: $*"
}

inf() {
    echo "\n$(date '+%Y-%m-%d %H:%M:%S.%N')    INFO: $*"
}

wrn() {
    echo "\n$(date '+%Y-%m-%d %H:%M:%S.%N') WARNING: $*\n"
}

err() {
    echo "\n$(date '+%Y-%m-%d %H:%M:%S.%N')   ERROR: $*\n"
}

err_exit() {
    err "${1}"
    if [ ! -z ${2} ]
    then
        exit ${2}
    fi
}

warn_noncritical() {
    # for failures that shouldn't halt the overall workflow (e.g. ghcr/gcloud
    # login) -- warn immediately, and queue for a recap right before this
    # invocation exits, so it isn't missed among everything else logged
    wrn "${1}"
    NONCRIT_WARNINGS="${NONCRIT_WARNINGS}- ${1}
"
}

print_noncritical_warnings() {
    [ -z "${NONCRIT_WARNINGS}" ] && return 0
    wrn "Non-critical warnings from this run:
${NONCRIT_WARNINGS}"
}

# This switch-case calls a function with the same name as the first argument
# passed to this script and passes rest of the arguments to the function itself
exec_func() {
    # set here (not before the pipe this function is invoked from) so it's
    # this process's own EXIT trap -- fires even when err_exit() below (or
    # anything called transitively from ${cmd}) exits early
    trap print_noncritical_warnings EXIT
    inf "Executing '$*' with config:"
    check_cmd cat ${CONFIG_YAML}
    # shift positional arguments so that arg 2 becomes arg 1, etc.
    cmd=${1}
    shift 1
    ${cmd} "$@" 2>&1 || err_exit "Failed executing: ${cmd} $*" 1
}

case $1 in
    *   )
        exec_func "$@" | tee -a "${IXOPS_LOG}"
    ;;
esac
