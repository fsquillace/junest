#!/usr/bin/env bash
#
# Dependencies:
#   None
#
# vim: ft=sh

#######################################
# Create bin wrappers
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
# Arguments:
#   force ($1?)              : Create bin wrappers even if the bin file exists.
#                              Defaults to false.
# Returns:
#   None
# Output:
#   None
#######################################
function create_wrappers() {
    local PATH="${JUNEST_ORIGINAL_PATH:-"$PATH"}"
    local force=${1:-false}
    local bin_path=${2:-/usr/bin}
    bin_path=${bin_path%/}
    mkdir -p "${JUNEST_HOME}${bin_path}_wrappers"
    # Arguments inside a variable (i.e. `JUNEST_ARGS`) separated by quotes
    # are not recognized normally unless using `eval`. More info here:
    # https://github.com/fsquillace/junest/issues/262
    # https://github.com/fsquillace/junest/pull/287
    cat <<EOF > "${JUNEST_HOME}/usr/bin/junest_wrapper"
#!/usr/bin/env bash

eval "junest_args_array=(\${JUNEST_ARGS:-ns})"
junest "\${junest_args_array[@]}" -- \$(basename \${0}) "\$@"
EOF
    chmod +x "${JUNEST_HOME}/usr/bin/junest_wrapper"

    cd "${JUNEST_HOME}${bin_path}" || return 1
    for file in *
    do
        [[ -d $file ]] && continue
        # Symlinks outside junest appear as broken even though they are correct
        # within a junest session. The following do not skip broken symlinks:
        [[ -x $file || -L $file ]] || continue
        if [[ -e ${JUNEST_HOME}${bin_path}_wrappers/$file ]] && ! $force
        then
            continue
        fi
        rm -f "${JUNEST_HOME}${bin_path}_wrappers/$file"
        ln -s "${JUNEST_HOME}/usr/bin/junest_wrapper" "${JUNEST_HOME}${bin_path}_wrappers/$file"
    done

    # Remove wrappers no longer needed
    cd "${JUNEST_HOME}${bin_path}_wrappers" || return 1
    for file in *
    do
        [[ -e ${JUNEST_HOME}${bin_path}/$file || -L ${JUNEST_HOME}${bin_path}/$file ]] || rm -f "$file"
    done

}
