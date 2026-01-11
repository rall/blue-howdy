#!/bin/bash
set -uexo pipefail

dnf5 -y --refresh copr enable ronnypfannschmidt/howdy-beta
# install packages into the ostree deployment
rpm-ostree install howdy howdy-gtk
dnf5 -y copr disable ronnypfannschmidt/howdy-beta
