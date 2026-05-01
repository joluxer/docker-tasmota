#!/bin/bash 
#  cb.sh
#   Created on: 09.05.2025
#       Author: lode
# Container cross-build prefix

PROGDIR="$(dirname $(readlink -f "$0"))"

# some fallbacks for undefined environment variables
: ${XBPROJECT_ROOT:=$PROGDIR}
: ${XBCPREFIX:="tasmota-build"}

export XBPROJECT_ROOT XBCPREFIX

exec "$PROGDIR/Toolchain/xbcstp.sh"
