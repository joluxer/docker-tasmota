#!/bin/bash 
#  cb.sh
#   Created on: 09.05.2025
#       Author: lode
# Container cross-build prefix

PROGDIR="$(dirname $(readlink -f "$0"))"

# some fallbacks for undefined environment variables
: ${BUILDER_IMAGE:="${DOCKER_IMAGE:-blakadder/docker-tasmota}"}
: ${XBUILD_TARGET:=mcu}
: ${XBPROJECT_ROOT:=$PROGDIR}
: ${CBVARS_ENV:="$XBPROJECT_ROOT/ccodevars.env"}
: ${XBCPREFIX:="tasmota-build"}
: ${XBCRUNMIN:="720"}
: ${XBC_VOLUMES:="auto:target=$HOME/.platformio"}
: ${CBMOUNTS:="tasmota-build.mounts"}

export BUILDER_IMAGE XBUILD_TARGET XBPROJECT_ROOT CC CXX XBCPREFIX CBVARS_ENV CBMOUNTS XBCRUNMIN XBC_VOLUMES

# another fallback check for PATH containing the cross build forwarding scripts
echo $PATH | grep -q xbc-fwd || export PATH="$XBPROJECT_ROOT/Toolchain/xbc-fwd":$PATH

if [[ "pull-toolchain" == "${1}" ]]; then
  exec "$PROGDIR/Toolchain/xbcpull.sh"
elif [[ "linux" != "$XBUILD_TARGET" ]]; then
  exec "$PROGDIR/Toolchain/xbc-bash-root.sh" "$@"
fi
