#!/usr/bin/env bash

set -ex

pacman -Sy --noconfirm sudo

# Create a travis user
echo "travis ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/travis
chmod 'u=r,g=r,o=' /etc/sudoers.d/travis
groupadd --gid "2000" "travis"
useradd --create-home --uid "2000" --gid "2000" --shell /usr/bin/false "travis"

# Here do not make any validation (-n) because it will be done later on in the Ubuntu host directly
cd /build
runuser -u travis -- /build/bin/junest build -n
