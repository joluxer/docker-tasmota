#!/bin/bash 
#  cb.sh
#   Created on: 09.05.2025
#       Author: lode
# Container cross-build prefix

PROGDIR="$(dirname $(readlink -f "$0"))"

source "$PROGDIR/cbconfvars.sh"

# another fallback check for PATH containing the cross build forwarding scripts
echo $PATH | grep -q xbc-fwd || export PATH="$XBPROJECT_ROOT/Toolchain/xbc-fwd":$PATH

if [[ "pull-toolchain" == "${1}" ]]; then
  exec "$PROGDIR/Toolchain/xbcpull.sh"
elif [[ "linux" != "$XBUILD_TARGET" ]]; then
  exec "$PROGDIR/Toolchain/xbc-bash.sh" "$@"
fi
