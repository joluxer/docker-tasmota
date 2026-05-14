#!/bin/bash
# custom-compile.sh — Tasmota build wrapper
#
# When the Toolchain directory is present, builds run via a persistent Docker
# container using the XBC toolchain system (xbcstrt.sh / xbld.sh).
# Without the Toolchain directory, falls back to a simple ephemeral docker run.
#
# Prerequisites:
#   - The Tasmota repo is already cloned under $TASMOTA_DIR
#   - user_config_override.h and/or platformio_override.ini are placed
#     in the same directory as this script
#   - Docker is installed and running
#
# Usage:
#   ./custom-compile.sh tasmota tasmota-sensors   # one or more targets
#   ./custom-compile.sh                           # all targets (caution!)
#
# Environment variables (optional, set before invoking):
#   DOCKER_IMAGE   — alternative Docker image (default: blakadder/docker-tasmota)
#   TASMOTA_DIR    — Tasmota repo directory (default: $SCRIPT_DIR/Tasmota)
#   XBCRUNMIN      — container timeout in minutes (default: 240, XBC mode only)
#   USE_TEE=1      — write output to terminal AND log file simultaneously

set -euo pipefail

# --- XBC configuration -------------------------------------------------------

PROGDIR=$(dirname "$(readlink -f "$0")")
TOOLDIR="$PROGDIR/Toolchain"

source "$PROGDIR/cbconfvars.sh"

# --- Project configuration ---------------------------------------------------

CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"

TASMOTA_DIR="${TASMOTA_DIR:-${PROGDIR}/Tasmota}"
LOG_FILE="${PROGDIR}/docker-tasmota.log"

# --- Check prerequisites -----------------------------------------------------

if ! command -v docker &>/dev/null; then
    echo -e "\nNo Docker detected. Please install docker:"
    echo -e "\n\tcurl -fsSL https://get.docker.com -o get-docker.sh"
    echo -e "\tsh get-docker.sh\n"
    exit 1
fi

if [[ ! -d "${TASMOTA_DIR}" ]]; then
    echo -e "\nNo Tasmota directory found at: ${TASMOTA_DIR}"
    echo -e "Please clone the repository first:"
    echo -e "\n\tgit clone https://github.com/arendst/Tasmota.git --branch development\n"
    exit 1
fi

# --- Validate build targets --------------------------------------------------

if [[ $# -gt 0 ]]; then
    for target in "$@"; do
        if [[ "${target}" != tasmota* ]]; then
            echo -e "\e[31mInvalid build target: '${target}'"
            echo -e "All targets must start with 'tasmota'.\e[0m"
            exit 1
        fi
    done
    echo -e "Compiling builds:"
    printf '  %s\n' "$@"
    echo
else
    echo -e "\e[31mNo targets specified — ALL builds will be compiled!"
    echo -e "\e[7mPress Ctrl+C to abort (4 seconds...)\e[0m"
    sleep 4
fi

# --- Copy override files into repo -------------------------------------------

if [[ -f "${PROGDIR}/user_config_override.h" ]]; then
    cp "${PROGDIR}/user_config_override.h" \
       "${TASMOTA_DIR}/tasmota/user_config_override.h"
    echo -e "Using your user_config_override.h and overwriting the existing file\n"
fi

if [[ -f "${PROGDIR}/platformio_override.ini" ]]; then
    cp "${PROGDIR}/platformio_override.ini" \
       "${TASMOTA_DIR}/platformio_override.ini"
    echo -e "Using your platformio_override.ini and overwriting the existing file\n"
fi

# --- Run build ---------------------------------------------------------------

echo "Compiling..."

if [[ -d "$TOOLDIR" ]]; then
    # XBC mode: delegate to persistent container via xbld.sh
    
    export DOCKER_TTY=""
    [[ -t 1 ]] && DOCKER_TTY="-t"
    
    if [[ $# -gt 0 ]]; then
        TARGET_ARGS=()
        for target in "$@"; do
            TARGET_ARGS+=(-e "${target}")
        done
        
        if [[ "${QUIET:-0}" != "1" ]]; then
            "$TOOLDIR/xbld.sh" pio run -d "${TASMOTA_DIR}" "${TARGET_ARGS[@]}" 2>&1 | tee "${LOG_FILE}"
        else
            "$TOOLDIR/xbld.sh" pio run -d "${TASMOTA_DIR}" "${TARGET_ARGS[@]}" >"${LOG_FILE}" 2>&1
        fi
    else
        if [[ "${QUIET:-0}" != "1" ]]; then
            "$TOOLDIR/xbld.sh" pio run -d "${TASMOTA_DIR}" 2>&1 | tee "${LOG_FILE}"
        else
            "$TOOLDIR/xbld.sh" pio run -d "${TASMOTA_DIR}" >"${LOG_FILE}" 2>&1
        fi
    fi
else
    # Fallback mode: ephemeral docker run, no Toolchain directory present
    DOCKER_TTY=""
    [[ -t 1 ]] && DOCKER_TTY="-it"

    DOCKER_BASE=(
        docker run
        ${DOCKER_TTY}
        --rm
        -v "${TASMOTA_DIR}:/tasmota"
        -e HOST_UID="${UID}"
        -e HOST_GID="${GID:-$(id -g)}"
        "${BUILDER_IMAGE}"
    )

    if [[ $# -gt 0 ]]; then
        TARGET_ARGS=()
        for target in "$@"; do
            TARGET_ARGS+=(-e "${target}")
        done

        if [[ "${USE_TEE:-0}" == "1" ]]; then
            "${DOCKER_BASE[@]}" "${TARGET_ARGS[@]}" 2>&1 | tee "${LOG_FILE}"
        else
            "${DOCKER_BASE[@]}" "${TARGET_ARGS[@]}" >"${LOG_FILE}" 2>&1
        fi
    else
        if [[ "${USE_TEE:-0}" == "1" ]]; then
            "${DOCKER_BASE[@]}" 2>&1 | tee "${LOG_FILE}"
        else
            "${DOCKER_BASE[@]}" >"${LOG_FILE}" 2>&1
        fi
    fi
fi

echo -e "\r${CHECK_MARK} Finished!  \tCompilation log in docker-tasmota.log\n"

# --- Copy binaries to script directory ---------------------------------------

if [[ $# -gt 0 ]]; then
    echo -e "Output files:"
    for target in "$@"; do
        src_pattern="${TASMOTA_DIR}/build_output/firmware/${target}"
        map_pattern="${TASMOTA_DIR}/build_output/map/${target}"
        copied=0
        src_files=()
        mapfile -t src_files < <(
          (
            shopt -s nullglob
            printf '%s\n' \
              "${src_pattern}.bin" \
              "${src_pattern}"-*.bin \
              "${src_pattern}.bin.gz" \
              "${src_pattern}"-*.bin.gz \
              "${src_pattern}"*.elf \
              "${map_pattern}"*.map*
          ) | sort -u
        )
        for src_file in "${src_files[@]}"; do
            [[ -f "${src_file}" ]] || continue
            cp "${src_file}" "${PROGDIR}/"
            echo -e "  ${CHECK_MARK} $(basename "${src_file}")"
            copied=1
        done
        if [[ "${copied}" -eq 0 ]]; then
            echo -e "  \e[31m\e[5mWARNING:\e[0m No output file found for '${target}'."
            echo -e "  Check compilation log: ${LOG_FILE}"
        fi
    done
    echo
fi

echo -e "Find your builds in ${TASMOTA_DIR}/build_output/firmware\n"
