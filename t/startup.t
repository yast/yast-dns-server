#!/bin/sh
# a TAP compatible test for
# yast dns-server startup xxx

# quick and dirty: fail early
set -eu

# test plan
echo 1..6

YAST=/usr/sbin/yast

echo "# Although yast dns-server installs the package if needed, let's assume"
echo "# and check that bind (named) is installed and the service disabled"
rpm -qi bind > /dev/null
systemctl is-enabled named | grep disabled
echo "ok 1 initial state"

$YAST dns-server startup show 2>&1 |grep "server needs manual starting"
echo "ok 2 show: disabled status properly displayed"

$YAST dns-server startup atboot
systemctl is-enabled named | grep enabled
echo "ok 3 atboot: service enabled"

$YAST dns-server startup show 2>&1 |grep "server is enabled in the boot process"
echo "ok 4 show: enabled status properly displayed"

$YAST dns-server startup manual
systemctl is-enabled named | grep disabled
echo "ok 5 manual: service disabled"

$YAST dns-server startup show 2>&1 |grep "server needs manual starting"
echo "ok 6 show: disabled status properly displayed"
