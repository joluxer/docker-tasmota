#!/bin/bash 
#  cb.sh
#   Created on: 09.05.2025
#       Author: lode
# Container cross-build prefix

PROGDIR="$(dirname $(readlink -f "$0"))"

source "$PROGDIR/cbconfvars.sh"

exec "$PROGDIR/Toolchain/xbcstp.sh"
