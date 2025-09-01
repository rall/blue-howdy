#!/bin/bash
set -uexo pipefail

dnf5 -y --refresh copr enable principis/howdy-beta
# install packages into the ostree deployment
rpm-ostree install howdy howdy-gtk
dnf5 -y copr disable principis/howdy-beta

# place policy source into image
install -Dm0644 /ctx/howdy_gdm.te /usr/share/selinux/howdy/howdy_gdm.te

# install SELinux policy
checkmodule -M -m -o /usr/share/selinux/howdy/howdy_gdm.mod \
                     /usr/share/selinux/howdy/howdy_gdm.te
semodule_package -o /usr/share/selinux/howdy/howdy_gdm.pp \
                 -m /usr/share/selinux/howdy/howdy_gdm.mod
semodule -i /usr/share/selinux/howdy/howdy_gdm.pp
