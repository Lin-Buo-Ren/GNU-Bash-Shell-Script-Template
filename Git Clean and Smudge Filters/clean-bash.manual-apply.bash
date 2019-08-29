#!/usr/bin/env bash
# shellcheck disable=SC2034

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

## Runtime Dependencies Checking
declare\
    runtime_dependency_checking_result=still-pass\
    required_software

for required_command in \
    basename\
    dirname\
    realpath; do
    if ! command -v "${required_command}" &>/dev/null; then
        runtime_dependency_checking_result=fail

        case "${required_command}" in
            basename\
            |dirname\
            |realpath)
                required_software='GNU Coreutils'
                ;;
            *)
                required_software="${required_command}"
                ;;
        esac

        printf --\
            'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n'\
            "${required_software}" 1>&2
        unset required_software
    fi
done; unset required_command required_software

if [ "${runtime_dependency_checking_result}" = fail ]; then
    printf --\
        'Error: Runtime dependency checking fail, the progrom cannot continue.\n' 1>&2
    exit 1
fi; unset runtime_dependency_checking_result

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v "BASH_SOURCE[0]" ]; then
    RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
    RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
    RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
    RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
    RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
    declare -r\
        RUNTIME_EXECUTABLE_FILENAME\
        RUNTIME_EXECUTABLE_DIRECTORY\
        RUNTIME_EXECUTABLE_PATHABSOLUTE\
        RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar RUNTIME_COMMANDLINE_PARAMETERS=("${@}")

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init(){
    local target_file=''

    if ! process_commandline_parameters target_file; then
        printf --\
            'Error: %s: Invalid command-line parameters.\n'\
            "${FUNCNAME[0]}"\
            1>&2
        print_help
        exit 1
    fi

    if ! check_runtime_dependencies; then
        exit 1
    fi

    global_temp_directory="$(mktemp --tmpdir --directory "${RUNTIME_EXECUTABLE_NAME}.XXXX")"
    declare -gr global_temp_directory

    declare -r temp_file_name=stdout.bash

    "${RUNTIME_EXECUTABLE_DIRECTORY}"/clean-bash.bash <"${target_file}" >"${global_temp_directory}/${temp_file_name}"
    cat "${global_temp_directory}/${temp_file_name}" >"${target_file}"

    exit 0
}; declare -fr init

check_runtime_dependencies(){
    for a_command in cat mktemp mv; do
        if ! command -v "${a_command}" &>/dev/null; then
            printf 'ERROR: %s command not found.\n' "${a_command}" 1>&2
            return 1
        fi
    done
    return 0
}

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
    printf 'An error occurred and the script is prematurely aborted\n' 1>&2
    return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
    rm --recursive --force "${global_temp_directory}"
    return 0
}; declare -fr trap_exit; trap trap_exit EXIT

trap_return(){
    local returning_function="${1}"

    printf 'DEBUG: %s: returning from %s\n' "${FUNCNAME[0]}" "${returning_function}" 1>&2
}; declare -fr trap_return

trap_interrupt(){
    printf '\n' # Separate previous output
    printf 'Recieved SIGINT, script is interrupted.' 1>&2
    return 1
}; declare -fr trap_interrupt; trap trap_interrupt INT

print_help(){
    printf 'Currently no help messages are available for this program\n' 1>&2
    return 0
}; declare -fr print_help;

process_commandline_parameters() {
    if [ $# -ne 1 ]; then
        printf -- \
            '%s: FATAL: Wrong function augument count.\n' \
            "${FUNCNAME[0]}" \
            >&2
        exit 1
    fi

    local -n target_file_ref="${1}"; shift 1

    if [ "${#RUNTIME_COMMANDLINE_PARAMETERS[@]}" -eq 0 ]; then
        print_help
        exit 0
    fi

    # modifyable parameters for parsing by consuming
    local -a parameters=("${RUNTIME_COMMANDLINE_PARAMETERS[@]}")

    # Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer it activation till returning(Y: Do debug)
    local enable_debug=N

    while true; do
        if [ "${#parameters[@]}" -eq 0 ]; then
            break
        else
            case "${parameters[0]}" in
                --help\
                |-h)
                    print_help;
                    exit 0
                    ;;
                --debug\
                |-d)
                    enable_debug=Y
                    ;;
                --*)
                    printf 'ERROR: Unknown command-line option "--%s"\n' "${parameters[0]}" >&2
                    return 1
                    ;;
                *)
                    if [ -n "${target_file_ref}" ]; then
                        printf -- \
                            '%s: Error: Only one file can be cleaned at once.\n' \
                            "${FUNCNAME[0]}" \
                            >&2
                        return 1
                    fi
                    target_file_ref="${parameters[0]}"
                    ;;
            esac
            # shift array by 1 = unset 1st then repack
            unset 'parameters[0]'
            if [ "${#parameters[@]}" -ne 0 ]; then
                parameters=("${parameters[@]}")
            fi
        fi
    done

    if [ "${enable_debug}" = Y ]; then
        trap 'trap_return "${FUNCNAME[0]}"' RETURN
        set -o xtrace
    fi
    return 0
}; declare -fr process_commandline_parameters;

init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
## GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="@@GBSST_VERSION@@"
## You may rebase your script to incorporate new features and fixes from the template
