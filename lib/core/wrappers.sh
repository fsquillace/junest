

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
        cat <<EOF > ${JUNEST_HOME}/usr/bin_wrappers/${file}
#!/usr/bin/env bash

JUNEST_ARGS=\${JUNEST_ARGS:-ns --fakeroot}

junest \${JUNEST_ARGS} -- ${file} "\$@"
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
