# some fallbacks for undefined environment variables
: ${BUILDER_IMAGE:="${DOCKER_IMAGE:-blakadder/docker-tasmota}"}
: ${XBUILD_TARGET:=mcu}
: ${XBPROJECT_ROOT:=$PROGDIR}
: ${CBVARS_ENV:="$XBPROJECT_ROOT/cbvars.env"}
: ${XBCPREFIX:="tasmota-build"}
: ${XBCRUNMIN:="720"}
: ${XBC_VOLUMES:="auto:target=$HOME/.platformio"}
: ${CBMOUNTS:="tasmota-build.mounts"}

export BUILDER_IMAGE XBUILD_TARGET XBPROJECT_ROOT CC CXX XBCPREFIX CBVARS_ENV CBMOUNTS XBCRUNMIN XBC_VOLUMES

