#!/usr/bin/env bash

set -e

IMG_PATH=$1

set -u

MAX_OLD_IMAGES=30

# ARCH can be one of: x86, x86_64, arm
HOST_ARCH=$(uname -m)
if [ $HOST_ARCH == "i686" ] || [ $HOST_ARCH == "i386" ]
then
    ARCH="x86"
elif [ $HOST_ARCH == "x86_64" ]
then
    ARCH="x86_64"
elif [[ $HOST_ARCH =~ .*(arm).* ]]
then
    ARCH="arm"
else
    echo "Unknown architecture ${HOST_ARCH}" >&2
    exit 11
fi

if [[ "$TRAVIS_BRANCH" == "master" ]]
then

    export AWS_DEFAULT_REGION=eu-west-1
    # Upload image
    # The put is done via a temporary filename in order to prevent outage on the
    # production file for a longer period of time.
    cp ${IMG_PATH} ${IMG_PATH}.temp
    aws s3 cp ${IMG_PATH}.temp s3://junest-repo/junest/
    aws s3 mv s3://junest-repo/junest/${IMG_PATH}.temp s3://junest-repo/junest/${IMG_PATH}
    aws s3api put-object-acl --acl public-read --bucket junest-repo --key junest/${IMG_PATH}

    DATE=$(date +'%Y-%m-%d-%H-%M-%S')

    aws s3 cp ${IMG_PATH} s3://junest-repo/junest/${IMG_PATH}.${DATE}

    # Cleanup old images
    aws s3 ls s3://junest-repo/junest/junest-${ARCH}.tar.gz. | awk '{print $4}' | head -n -${MAX_OLD_IMAGES} | xargs -I {} s3 rm "s3://junest-repo/junest/{}"

    # Test the newly deployed image can be downloaded correctly
    junest setup
    junest -- echo "Installed JuNest (\$(uname -m))"
    yes | junest setup --delete
fi
