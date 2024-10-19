#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
/bin/rm -f /tmp/install-for-docker.sh /tmp/install-docker.sh
wget -c -T 9 -t 9 -O /tmp/install-for-docker.sh \
"https://raw.githubusercontent.com/icebluey/docker/refs/heads/master/install/ubuntu/install-for-docker.sh"
wget -c -T 9 -t 9 -O /tmp/install-docker.sh \
"https://raw.githubusercontent.com/icebluey/docker/refs/heads/master/install/ubuntu/install-docker.sh"
/bin/bash /tmp/install-for-docker.sh
/bin/bash /tmp/install-docker.sh
/bin/rm -vf /tmp/install-for-docker.sh /tmp/install-docker.sh
exit
