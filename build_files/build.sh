#!/bin/bash

set -ouex pipefail

dnf5 --assumeyes copr enable principis/howdy-beta
dnf5 --refresh --assumeyes install howdy howdy-gtk
dnf5 --assumeyes copr disable principis/howdy-beta
