function parallel_not_empty {
    # Ensure that an expression is not empty
    # then cleanup and quit if it is
    local description=$1
    local check=$2
    if [ -z "$check" ]; then
        >&2 echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cannot run without ${description}"
        parallel_cleanup "${MISSING_INPUT}"
    fi
    return 0
}
export -f parallel_not_empty

function parallel_log_setting {
    # Make sure a setting is provided
    # and report it
    local description=$1
    local setting=$2
    parallel_not_empty "date stamp" "${STAMP}"
    parallel_not_empty "$description" "$setting"
    >&2 echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: ${description} is ${setting}"
}
export -f parallel_log_setting

function parallel_report {
    # Inform the user of a non-zero return
    # code, cleanup, and if an exit
    # message is provided as a third argument
    # also exit
    local rc=$1
    local description=$2
    local exit_message=$3
    >&2 echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: ${description} exited with code $rc"
    if [ -z "$exit_message" ]; then
        >&2 echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: continuing . . ."
    else
        >&2 echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: $exit_message"
        parallel_cleanup $rc
    fi
    return $rc
}
export -f parallel_report

function parallel_check_exists {
    # Make sure a file or folder or link exists
    # then cleanup and quit if not
    local file_name=$1
    parallel_log_setting "file or directory name that must exist" "$file_name"
    if ! [ -e "$file_name" ]; then
        >&2 echo "${STAMP} ${PARALLEL_PID} ${PARALLEL_JOBSLOT} ${PARALLEL_SEQ}: cannot find $file_name"
        parallel_cleanup "$MISSING_FILE"
    fi
    return 0
}
export -f parallel_check_exists

parallel_cleanup_function=""

function parallel_cleanup {

    # Version of the function cleanup
    # for use with GNU parallel.

    local rc=$1
    >&2 echo "***"
    >&2 echo "${STAMP}" "${PARALLEL_PID}" \
                        "${PARALLEL_JOBSLOT}" \
                        "${PARALLEL_SEQ}: exiting subprocess cleanly with code ${rc} . . ."
    if [ -n "$parallel_cleanup_function" ]; then
        if [[ $parallel_cleanup_function == parallel_cleanup_* ]]
        then
            $parallel_cleanup_function ${rc}
        else
            >&2 echo "${STAMP}" "${PARALLEL_PID}" \
                                "${PARALLEL_JOBSLOT}" \
                                "${PARALLEL_SEQ}: not calling $parallel_cleanup_function"
        fi
    fi
    >&2 echo "${STAMP}" "${PARALLEL_PID}" \
                        "${PARALLEL_JOBSLOT}" \
                        "${PARALLEL_SEQ}: . . . all done with code ${rc}"
    return $rc
}
export -f parallel_cleanup

function kids {

    # TODO make sure recursive output is
    # TODO not on multiple lines

    local pid="$1"

    parallel_not_empty "pid to check for children" "$pid"

    for t in /proc/${pid}/task/*; do
        local children="${t}/children"
        if [ -e "$children" ]; then
            for kid in $(cat ${children}); do
                echo $kid
                kids "$kid"
            done
        fi
    done

    return 0
}
export -f kids

