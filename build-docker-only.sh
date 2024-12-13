#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
CC=gcc
export CC
CXX=g++
export CXX

# _docker_mainline='27.3'
_docker_mainline="${1}"
_major=$(echo ${_docker_mainline} | awk -F\. '{print $1}')
_minor=$(echo ${_docker_mainline} | awk -F\. '{print $2}')

_moby_tag_f="$(wget -qO- 'https://github.com/moby/moby/tags' | grep -i 'href="/moby/moby/releases/tag/' | sed 's|"|\n|g' | grep -i '/moby/moby/releases/tag/' | grep -ivE 'alpha|beta|rc' | sed 's|.*tag/||g' | sort -V | tail -n 1)"
_cli_tag_f="$(wget -qO- 'https://github.com/docker/cli/tags' | grep -i 'href="/docker/cli/releases/tag/' | sed 's|"|\n|g' | grep -i '/docker/cli/releases/tag/' | grep -ivE 'alpha|beta|rc' | sed 's|.*tag/||g' | sort -V | tail -n 1)"

_build_moby() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone 'https://github.com/moby/moby.git'
    cd moby
    _docker_tag=$(git tag | grep -ivE 'alpha|beta|rc|doc' | grep "v${_major}\.${_minor}" | sort -V | tail -n 1)
    _moby_tag=${_docker_tag:-$(git tag | grep -ivE 'alpha|beta|rc|doc' | grep -i '^[Vv][0-9]' | sort -V | tail -n 1)}
    git checkout "${_moby_tag}"
    export VERSION="${_moby_tag#v}"
    sed 's#VERSION=${VERSION:-dev.*#VERSION=${VERSION:-$(git describe --match '\''v[0-9]*'\'' --always --tags | sed '\''s/^v//'\'' 2>/dev/null || echo "unknown-version")}#g' -i hack/make.sh
    echo
    grep 'VERSION=' hack/make.sh
    echo
    make binary
    /bin/cp -vfr bundles/binary/* /tmp/_output_assets/binary/
    sleep 1
    cd /tmp
    /bin/rm -fr "${_tmp_dir}"
    /bin/rm -fr /tmp/.moby_ver
    echo "${_moby_tag#v}" > /tmp/.moby_ver
    export VERSION=''
}

_build_docker_cli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone 'https://github.com/docker/cli.git'
    cd cli
    _docker_tag=$(git tag | grep -ivE 'alpha|beta|rc|doc' | grep "v${_major}\.${_minor}" | sort -V | tail -n 1)
    _cli_tag=${_docker_tag:-$(git tag | grep -ivE 'alpha|beta|rc|doc' | grep -i '^[Vv][0-9]' | sort -V | tail -n 1)}
    git checkout "${_cli_tag}"
    export VERSION="${_cli_tag#v}"
    docker buildx bake
    /bin/cp -vfr build/docker-linux-amd64 /tmp/_output_assets/binary/docker
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    /bin/rm -fr /tmp/.cli_ver
    echo "${_cli_tag#v}" > /tmp/.cli_ver
    export VERSION=''
}

_reset_docker() {
    /bin/systemctl stop docker.socket docker.service containerd.service
    /bin/rm -fr /var/lib/docker/* /var/lib/containerd/* /mnt/docker-data/*
    /bin/systemctl start containerd.service
    sleep 1
    /bin/systemctl start docker.service
}

mkdir -p /tmp/_output_assets/binary
_build_moby
_reset_docker
_build_docker_cli

if [[ "$(cat /tmp/.moby_ver)" == "$(cat /tmp/.cli_ver)" ]]; then
    _docker_ver="$(cat /tmp/.moby_ver)"
else
    echo "moby version: $(cat /tmp/.moby_ver)"
    echo "docker cli version: $(cat /tmp/.cli_ver)"
    echo
    exit 1
fi

cd /tmp/_output_assets
/bin/ls -la binary
/bin/mkdir -p usr/libexec/docker/cli-plugins etc/docker
/bin/cp -fr binary usr/bin

##############################################################################
# docker-init
mkdir tini
cd tini
_tini_ver="$(wget -qO- 'https://github.com/krallin/tini/releases' | grep -i 'tini-amd64' | grep -i 'href="/krallin/tini/releases/download' | sed 's|"|\n|g' | grep -i '/krallin/tini/releases/download' | grep -ivE 'alpha|beta|rc' | sed -e 's|.*download/||g' -e 's|/t.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 9 -T 9 "https://github.com/krallin/tini/releases/download/${_tini_ver}/tini-static-amd64"
sleep 1
install -v -c -m 0755 tini-static-amd64 ../usr/bin/docker-init
sleep 1
cd ..
/bin/rm -fr tini

##############################################################################
# docker-compose
mkdir compose
cd compose
_compose_ver="$(wget -qO- 'https://github.com/docker/compose/releases/' | grep -i '<a href="/docker/compose/tree/' | sed 's/ /\n/g' | grep -i '^href="/docker/compose/tree/' | sed 's@href="/docker/compose/tree/@@g' | sed 's/"//g' | grep -ivE 'alpha|beta|rc' | sed 's|[Vv]||g' | sort -V | uniq | tail -n 1)"
wget -q -c -t 9 -T 9 "https://github.com/docker/compose/releases/download/v${_compose_ver}/docker-compose-linux-x86_64.sha256"
wget -q -c -t 9 -T 9 "https://github.com/docker/compose/releases/download/v${_compose_ver}/docker-compose-linux-x86_64"
echo
sleep 1
sha256sum -c "docker-compose-linux-x86_64.sha256"
rc=$?
if [[ $rc != 0 ]]; then
    echo ' sha256 of docker-compose mismatch '
    exit 1
fi
sleep 1
/bin/rm -f *.sha*
echo
install -v -c -m 0755 docker-compose-linux-x86_64 ../usr/libexec/docker/cli-plugins/docker-compose
sleep 1
cd ..
/bin/rm -fr compose

##############################################################################
# docker-buildx
mkdir buildx
cd buildx
_buildx_ver="$(wget -qO- 'https://github.com/docker/buildx/releases' | grep -i 'a href="/docker/buildx/releases/download/' | sed 's|"|\n|g' | grep -i '^/docker/buildx/releases/download/.*linux-amd64.*' | grep -ivE 'alpha|beta|rc[0-9]' | sed -e 's|.*/buildx-v||g' -e 's|\.linux.*||g' | sort -V | uniq | tail -n 1)"
wget -q -c -t 0 -T 9 "https://github.com/docker/buildx/releases/download/v${_buildx_ver}/buildx-v${_buildx_ver}.linux-amd64"
sleep 1
install -v -c -m 0755 "buildx-v${_buildx_ver}.linux-amd64" ../usr/libexec/docker/cli-plugins/docker-buildx
sleep 1
cd ..
/bin/rm -fr buildx

##############################################################################

echo '[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service
After=flanneld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target' > etc/docker/docker.service
sleep 1
chmod 0644 etc/docker/docker.service

##############################################################################

echo '[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target' > etc/docker/docker.socket
sleep 1
chmod 0644 etc/docker/docker.socket

##############################################################################

echo '{
  "dns": [
    "8.8.8.8"
  ],
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "storage-driver": "overlay2"
}' > etc/docker/daemon.json.example
sleep 1
chmod 0644 etc/docker/daemon.json.example

echo '{
  "dns": [
    "8.8.8.8"
  ],
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "storage-driver": "overlay2",
  "data-root": "/var/lib/docker",
  "insecure-registries": [
    "10.10.10.10:443"
  ]
}' > etc/docker/daemon.json.example2
sleep 1
chmod 0644 etc/docker/daemon.json.example2

##############################################################################

echo '
cd "$(dirname "$0")"
rm -f /lib/systemd/system/docker.service
rm -f /lib/systemd/system/docker.socket
[[ -f /etc/docker/daemon.json ]] || /bin/cp -v /etc/docker/daemon.json.example /etc/docker/daemon.json
[[ -d /var/lib/docker ]] || install -v -m 0710 -d /var/lib/docker && chown root:root /var/lib/docker
[[ -d /var/lib/docker-engine ]] || install -v -m 0755 -d /var/lib/docker-engine && chown root:root /var/lib/docker-engine
[[ -f /var/lib/docker-engine/distribution_based_engine.json ]] || \
    echo '\''{"platform":"Docker Engine - Community","engine_image":"engine-community-dm","containerd_min_version":"1.2.0-beta.1","runtime":"host_install"}'\'' > /var/lib/docker-engine/distribution_based_engine.json && \
    chmod 0644 /var/lib/docker-engine/distribution_based_engine.json && chown root:root /var/lib/docker-engine/distribution_based_engine.json
[[ -d /etc/systemd/system/docker.service.d ]] || install -v -m 0755 -d /etc/systemd/system/docker.service.d && chown root:root /etc/systemd/system/docker.service.d
/bin/systemctl daemon-reload >/dev/null 2>&1 || :
install -v -c -m 0644 docker.service /lib/systemd/system/
install -v -c -m 0644 docker.socket /lib/systemd/system/
getent group docker >/dev/null 2>&1 || groupadd -r docker
sleep 1
/bin/systemctl daemon-reload >/dev/null 2>&1 || :
if ! $(/sbin/sysctl -a 2>/dev/null | grep -q -i "net.bridge.bridge-nf-call-iptables"); then modprobe br_netfilter; fi
' > etc/docker/.install.txt
sleep 1
chmod 0644 etc/docker/.install.txt

##############################################################################

echo '
systemctl daemon-reload > /dev/null 2>&1 || : 
sleep 1
systemctl stop docker.socket > /dev/null 2>&1 || : 
systemctl stop docker.service > /dev/null 2>&1 || : 
sleep 1
systemctl stop containerd.service > /dev/null 2>&1 || : 
sleep 1
ip link set docker0 down > /dev/null 2>&1 || : 
sleep 1
ip link delete docker0 > /dev/null 2>&1 || : 

systemctl disable docker.socket > /dev/null 2>&1 || : 
systemctl disable docker.service > /dev/null 2>&1 || : 
systemctl disable containerd.service > /dev/null 2>&1 || : 

rm -fr /run/containerd
rm -fr /run/docker.sock
rm -fr /var/run/containerd
rm -fr /var/run/docker.sock
#rm -fr /run/docker
#rm -fr /var/run/docker
' > etc/docker/.stop-disable.txt
sleep 1
chmod 0644 etc/docker/.stop-disable.txt

##############################################################################

find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
find usr/libexec/docker/cli-plugins/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'

echo
sleep 2
tar --format=gnu -Jcvf "docker-only-${_docker_ver}-1_amd64.tar.xz" usr etc
#tar --format=gnu -cf - usr etc | xz --threads=2 -v -f -z -9 > "docker-only-${_docker_ver}-1_amd64.tar.xz"
echo
sleep 2
sha256sum "docker-only-${_docker_ver}-1_amd64.tar.xz" > "docker-only-${_docker_ver}-1_amd64.tar.xz".sha256
sleep 2
/bin/rm -fr usr etc binary
echo ' done'
exit

