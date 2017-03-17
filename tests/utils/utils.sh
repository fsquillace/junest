OLD_CWD=${PWD}
function cwdSetUp(){
    ORIGIN_CWD=$(TMPDIR=/tmp mktemp -d -t junest-cwd.XXXXXXXXXX)
    cd $ORIGIN_CWD
}

function cwdTearDown(){
    rm -rf $ORIGIN_CWD
    cd $OLD_CWD
}

function junestSetUp(){
    JUNEST_HOME=$(TMPDIR=/tmp mktemp -d -t junest-home.XXXXXXXXXX)
    mkdir -p ${JUNEST_HOME}/etc/junest
    echo "JUNEST_ARCH=x86_64" > ${JUNEST_HOME}/etc/junest/info
    mkdir -p ${JUNEST_HOME}/etc/ca-certificates
}

function junestTearDown(){
    # the CA directories are read only and can be deleted only by changing the mod
    [ -d ${JUNEST_HOME}/etc/ca-certificates ] && chmod -R +w ${JUNEST_HOME}/etc/ca-certificates
    rm -rf $JUNEST_HOME
    unset JUNEST_HOME
}

function setUpUnitTests(){
    OUTPUT_DIR="${SHUNIT_TMPDIR}/output"
    mkdir "${OUTPUT_DIR}"
    STDOUTF="${OUTPUT_DIR}/stdout"
    STDERRF="${OUTPUT_DIR}/stderr"
}

function assertCommandSuccess(){
    $(set -e
      "$@" > $STDOUTF 2> $STDERRF
    )
    assertTrue "The command $1 did not return 0 exit status" $?
}

function assertCommandFail(){
    $(set -e
      "$@" > $STDOUTF 2> $STDERRF
    )
    assertFalse "The command $1 returned 0 exit status" $?
}

# $1: expected exit status
# $2-: The command under test
function assertCommandFailOnStatus(){
    local status=$1
    shift
    $(set -e
      "$@" > $STDOUTF 2> $STDERRF
    )
    assertEquals $status $?
}
