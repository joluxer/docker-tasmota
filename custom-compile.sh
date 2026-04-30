#!/bin/bash
# custom-compile.sh — Docker-Tasmota build wrapper without Git logic
#
# Prerequisites:
#   - The Tasmota repo is already cloned and checked out to the desired
#     state under ./Tasmota/ (relative to the directory of this script)
#   - user_config_override.h and/or platformio_override.ini are placed
#     in the same directory as this script
#
# Usage:
#   ./custom-compile.sh tasmota tasmota-sensors   # one or more targets
#   ./custom-compile.sh                           # all targets (caution!)
#
# Environment variables (optional, set before invoking):
#   DOCKER_IMAGE   — alternative Docker image (default: blakadder/docker-tasmota)
#   USE_TEE=1      — write output to terminal AND log file simultaneously

set -euo pipefail

# --- Konfiguration -----------------------------------------------------------

CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
TASMOTA_DIR="${SCRIPT_DIR}/Tasmota"
LOG_FILE="${SCRIPT_DIR}/docker-tasmota.log"

DOCKER_IMAGE="${DOCKER_IMAGE:-blakadder/docker-tasmota}"

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

if [[ -f "${SCRIPT_DIR}/user_config_override.h" ]]; then
    cp "${SCRIPT_DIR}/user_config_override.h" \
       "${TASMOTA_DIR}/tasmota/user_config_override.h"
    echo -e "Using your user_config_override.h and overwriting the existing file\n"
fi

if [[ -f "${SCRIPT_DIR}/platformio_override.ini" ]]; then
    cp "${SCRIPT_DIR}/platformio_override.ini" \
       "${TASMOTA_DIR}/platformio_override.ini"
    echo -e "Using your platformio_override.ini and overwriting the existing file\n"
fi

# --- Docker invocation -------------------------------------------------------

# Enable TTY only when running in an interactive terminal
DOCKER_TTY=""
[[ -t 1 ]] && DOCKER_TTY="-it"

DOCKER_BASE=(
    docker run
    ${DOCKER_TTY}
    --rm
    -v "${TASMOTA_DIR}:/tasmota"
    -e HOST_UID="${UID}"
    -e HOST_GID="${GID:-$(id -g)}"
    "${DOCKER_IMAGE}"
)

echo -n "Compiling..."

if [[ $# -gt 0 ]]; then
    # Pass targets as -e <target> -e <target> ...
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
    # Kein Target → alle Builds
    if [[ "${USE_TEE:-0}" == "1" ]]; then
        "${DOCKER_BASE[@]}" 2>&1 | tee "${LOG_FILE}"
    else
        "${DOCKER_BASE[@]}" >"${LOG_FILE}" 2>&1
    fi
fi

echo -e "\r${CHECK_MARK} Finished!  \tCompilation log in docker-tasmota.log\n"

# --- Copy binaries to script directory ---------------------------------------

if [[ $# -gt 0 ]]; then
    echo -e "Output files:"
    for target in "$@"; do
        src_pattern="${TASMOTA_DIR}/build_output/firmware/${target}"
        copied=0
        for src_file in "${src_pattern}"*.bin "${src_pattern}"*.bin.gz; do
            [[ -f "${src_file}" ]] || continue
            cp "${src_file}" "${SCRIPT_DIR}/"
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
