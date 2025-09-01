#!/bin/bash
set -ouex pipefail

dnf5 -y copr enable principis/howdy-beta
# install packages into the ostree deployment
rpm-ostree install howdy howdy-gtk
dnf5 -y copr disable principis/howdy-beta
