

function create_wrappers() {
    mkdir -p ${JUNEST_HOME}/usr/bin_wrappers

    cd ${JUNEST_HOME}/usr/bin
    for file in *
    do
        [[ -x $file ]] || continue
        if [[ -e ${JUNEST_HOME}/usr/bin_wrappers/$file ]]
        then
            continue
        fi
        # Arguments inside a variable (i.e. `JUNEST_ARGS`) separated by quotes
        # are not recognized normally unless using `eval`. More info here:
        # https://github.com/fsquillace/junest/issues/262
        cat <<EOF > ${JUNEST_HOME}/usr/bin_wrappers/${file}
#!/usr/bin/env bash

JUNEST_ARGS=\${JUNEST_ARGS:-ns --fakeroot}

eval junest \${JUNEST_ARGS[@]} -- ${file} "\$@"
EOF
        chmod +x ${JUNEST_HOME}/usr/bin_wrappers/${file}
    done

    # Remove wrappers no longer needed
    cd ${JUNEST_HOME}/usr/bin_wrappers
    for file in *
    do
        [[ -e ${JUNEST_HOME}/usr/bin/$file ]] || rm -f $file
    done

}
