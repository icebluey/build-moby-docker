#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
apt update -y -qqq
df -Th
ln -svf ../usr/share/zoneinfo/UTC /etc/localtime
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y tzdata
dpkg-reconfigure --frontend noninteractive tzdata

/bin/systemctl disable $(/bin/systemctl list-unit-files | grep -i -E 'docker|container|podman' | grep -iv 'container-getty' | awk '{print $1}' | sort -V | uniq | paste -sd" ")
/bin/systemctl stop $(/bin/systemctl list-unit-files | grep -i -E 'docker|container|podman' | grep -iv 'container-getty' | awk '{print $1}' | sort -V | uniq | paste -sd" ")

# delete firefox
apt autoremove --purge -y --allow-remove-essential $(dpkg -l | grep -i -E 'firefox|firebird|google-chrome-stable' | awk '{print $2}' | sort -V | uniq | paste -sd" ")

# delete microsoft
apt autoremove --purge -y --allow-remove-essential $(dpkg -l | grep -i -E 'dotnet|microsoft|libmono|mono-|monodoc|powershell' | awk '{print $2}' | sort -V | uniq | paste -sd" ")

# delete docker
apt autoremove --purge -y --allow-remove-essential $(dpkg -l | grep -i -E 'docker|container|moby' | awk '{print $2}' | sort -V | uniq | paste -sd" ")
apt autoremove --purge -y crun
apt autoremove --purge -y runc
/bin/rm -fr /etc/docker /usr/libexec/docker /etc/containerd /var/lib/containerd /var/lib/docker*

# delete mysql postgresql php google-cloud
/bin/systemctl disable postgresql.service
/bin/systemctl disable mysql.service
/bin/systemctl disable mysqld.service
/bin/systemctl stop postgresql.service
/bin/systemctl stop mysql.service
/bin/systemctl stop mysqld.service
apt autoremove --purge -y --allow-remove-essential $(dpkg -l | awk '$2 ~ /mysql|postgresql|google-cloud|mssql|msbuild|msodbcsql|^llvm-|^php[1-9]/ {print $2}' |  grep -iv libmysqlclient | sort -V | uniq | paste -sd" ")
/bin/rm -fr /var/lib/postgresql /var/lib/mysql

# delete snap
snap remove --purge lxd
snap remove --purge $(snap list | awk 'NR > 1 && $1 !~ /lxd/ && $1 !~ /snapd/ {print $1}' | sort -V | uniq | paste -sd" ")
snap remove --purge lxd
snap remove --purge snapd
_services=(
'snapd.socket'
'snapd.service'
'snapd.apparmor.service'
'snapd.autoimport.service'
'snapd.core-fixup.service'
'snapd.failure.service'
'snapd.recovery-chooser-trigger.service'
'snapd.seeded.service'
'snapd.snap-repair.service'
'snapd.snap-repair.timer'
'snapd.system-shutdown.service'
)
for _service in ${_services[@]}; do
    systemctl stop ${_service} >/dev/null 2>&1
done
sleep 3
for _service in ${_services[@]}; do
    systemctl disable ${_service} >/dev/null 2>&1
done
/bin/systemctl disable snapd.service
/bin/systemctl disable snapd.socket
/bin/systemctl disable snapd.seeded.service
/bin/systemctl stop snapd.service
/bin/systemctl stop snapd.socket
/bin/systemctl stop snapd.seeded.service
apt autoremove --purge lxd-agent-loader snapd
/bin/rm -rf ~/snap
/bin/rm -rf /snap
/bin/rm -rf /var/snap
/bin/rm -rf /var/lib/snapd
/bin/rm -rf /var/cache/snapd
/bin/rm -fr /tmp/snap.lxd
/bin/rm -fr /tmp/snap-private-tmp
/bin/rm -fr /usr/lib/snapd

/bin/rm -fr /usr/share/sbt
/bin/rm -fr /usr/share/gradle*
/bin/rm -fr /usr/share/miniconda*
/bin/rm -fr /usr/share/az_*
/bin/rm -fr /usr/share/swift*
/bin/rm -fr /usr/share/dotnet*
/bin/rm -fr /usr/lib/snapd
/bin/rm -fr /usr/lib/firefox
/bin/rm -fr /usr/lib/llvm*
/bin/rm -fr /usr/lib/mono
/bin/rm -fr /usr/lib/jvm
/bin/rm -fr /usr/lib/google-cloud-sdk*
/bin/rm -fr /opt/containerd
/bin/rm -fr /opt/mssql-tools
/bin/rm -fr /opt/google
/bin/rm -fr /opt/pipx
/bin/rm -fr /opt/az
/bin/rm -fr /opt/microsoft
/bin/rm -fr /usr/local/sqlpackage
/bin/rm -fr /usr/local/n
/bin/rm -fr /usr/local/aws*
/bin/rm -fr /usr/local/julia*
/bin/rm -fr /usr/local/share
/bin/rm -fr /usr/local/.ghcup
/bin/rm -fr /opt/hostedtoolcache

rm -fr /etc/apt/preferences.d/firefox*
/bin/systemctl stop systemd-resolved.service
/bin/systemctl stop systemd-timesyncd
/bin/systemctl stop unattended-upgrades
/bin/systemctl stop udisks2.service
/bin/systemctl disable systemd-resolved.service
/bin/systemctl disable systemd-timesyncd
/bin/systemctl disable unattended-upgrades
/bin/systemctl disable udisks2.service
/bin/rm -fr /etc/resolv.conf
echo "nameserver 8.8.8.8" >/etc/resolv.conf

df -Th
exit
