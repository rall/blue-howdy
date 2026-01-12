#!/bin/bash
set -uexo pipefail

# Detect Fedora version
FEDORA_VERSION=$(rpm -E %fedora)

if [[ "$FEDORA_VERSION" -ge 43 ]]; then
    # F43+ needs ronnypfannschmidt's fork (has Python 3.14 support + howdy-authselect)
    dnf5 -y --refresh copr enable ronnypfannschmidt/howdy-beta
    rpm-ostree install howdy howdy-gtk howdy-authselect
    dnf5 -y copr disable ronnypfannschmidt/howdy-beta
else
    # F42 and earlier use principis COPR (no howdy-authselect available)
    dnf5 -y --refresh copr enable principis/howdy-beta
    rpm-ostree install howdy howdy-gtk
    dnf5 -y copr disable principis/howdy-beta
fi
