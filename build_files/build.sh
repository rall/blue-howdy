#!/bin/bash
set -uexo pipefail

dnf5 -y --refresh copr enable ronnypfannschmidt/howdy-beta
rpm-ostree install howdy howdy-gtk howdy-authselect
dnf5 -y copr disable ronnypfannschmidt/howdy-beta
