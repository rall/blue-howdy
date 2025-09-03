# Strict shell for every recipe
set shell := ["bash", "-euo", "pipefail", "-c"]

# -------- Helpers --------

# Run command as root if needed
sudoif cmd +args='':
	@if [[ $EUID -ne 0 ]]; then sudo {{cmd}} {{args}}; else {{cmd}} {{args}}; fi

# Timestamp helper
ts := `date +%Y%m%d-%H%M%S`

# PAM paths and line to insert
GDM_PAM := "/etc/pam.d/gdm-password"
HOWDY_LINE := "auth sufficient pam_howdy.so"

# -------- Status --------

@pam-status:
	#!/usr/bin/env bash
	echo "==> ${GDM_PAM}"
	if [[ ! -f "${GDM_PAM}" ]]; then
	  echo "Missing: ${GDM_PAM}" >&2
	  exit 1
	fi
	echo "-- anchor (pam_selinux_permit.so):"
	grep -n 'pam_selinux_permit\.so' "${GDM_PAM}" || echo "(not found)"
	echo "-- howdy line:"
	grep -n 'pam_howdy\.so' "${GDM_PAM}" || echo "(not present)"
	echo
	read -p "Continue? [y/N]: " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	  echo "Aborted."
	  exit 1
	fi
	echo "==> /etc/pam.d/sudo"
	grep -n 'pam_howdy\.so' /etc/pam.d/sudo || echo "(not present)"
	echo
	echo "Tip: Lock screen or switch user to test Howdy at greeter BEFORE rebooting."

# -------- Apply / Revert --------

# Add Howdy to GDM and (optionally) sudo; idempotent, with backups
pam-add howdy_in_sudo="0":
	#!/usr/bin/env bash
	echo "!!! WARNING !!!"
	echo "This modifies PAM. TEST GNOME LOGIN AT THE GREETER BEFORE REBOOTING."
	echo "If the greeter fails: Ctrl+Alt+F3 -> login -> 'just pam-revert' -> 'sudo systemctl restart gdm'"
	echo

	# Backup current files
	just sudoif cp -a "${GDM_PAM}" "${GDM_PAM}.bak.${ts}"
	if [[ "${howdy_in_sudo}" == "1" && -f /etc/pam.d/sudo ]]; then
	  just sudoif cp -a /etc/pam.d/sudo "/etc/pam.d/sudo.bak.${ts}"
	fi

	# Inject into gdm-password only if missing
	if ! grep -q 'pam_howdy\.so' "${GDM_PAM}"; then
	  if grep -q 'pam_selinux_permit\.so' "${GDM_PAM}"; then
	    # Insert right after pam_selinux_permit.so
	    awk -v ins='${HOWDY_LINE}' '
	      { print }
	      $0 ~ /pam_selinux_permit\.so/ { print ins }
	    ' "${GDM_PAM}" > /tmp/gdm-password.new
	  else
	    # Fallback: make it the first auth line
	    awk -v ins='${HOWDY_LINE}' '
	      BEGIN { print ins }
	      { print }
	    ' "${GDM_PAM}" > /tmp/gdm-password.new
	  fi
	  just sudoif install -m 0644 /tmp/gdm-password.new "${GDM_PAM}"
	  rm -f /tmp/gdm-password.new
	  echo "Inserted Howdy into ${GDM_PAM}"
	else
	  echo "Howdy already present in ${GDM_PAM}"
	fi

	# Optional sudo integration: prepend as first line if missing
	if [[ "${howdy_in_sudo}" == "1" && -f /etc/pam.d/sudo ]]; then
	  if ! grep -q 'pam_howdy\.so' /etc/pam.d/sudo; then
	    awk -v ins='${HOWDY_LINE}' 'BEGIN { print ins } { print }' /etc/pam.d/sudo > /tmp/sudo.new
	    just sudoif install -m 0644 /tmp/sudo.new /etc/pam.d/sudo
	    rm -f /tmp/sudo.new
	    echo "Inserted Howdy into /etc/pam.d/sudo"
	  else
	    echo "Howdy already present in /etc/pam.d/sudo"
	  fi
	fi

	echo
	echo "Now lock your session or switch user to test the greeter BEFORE rebooting."

# Restore most recent backups
pam-revert:
	#!/usr/bin/env bash
	set -euo pipefail
	echo "Restoring most recent PAM backups (if any)..."
	latest_gdm="$(ls -1t ${GDM_PAM}.bak.* 2>/dev/null | head -n1 || true)"
	if [[ -n "${latest_gdm}" ]]; then
	  echo "Restoring ${latest_gdm} -> ${GDM_PAM}"
	  just sudoif install -m 0644 "${latest_gdm}" "${GDM_PAM}"
	else
	  echo "No backup found for ${GDM_PAM}"
	fi
	latest_sudo="$(ls -1t /etc/pam.d/sudo.bak.* 2>/dev/null | head -n1 || true)"
	if [[ -n "${latest_sudo}" ]]; then
	  echo "Restoring ${latest_sudo} -> /etc/pam.d/sudo"
	  just sudoif install -m 0644 "${latest_sudo}" /etc/pam.d/sudo
	else
	  echo "No backup found for /etc/pam.d/sudo (that’s fine if you didn’t add it)"
	fi
	echo "Done. You may run: sudo systemctl restart gdm"

# -------- Smoke tests --------

# Show where/how Howdy will be evaluated at greeter
@pam-grep:
	#!/usr/bin/env bash
	echo "Auth lines in ${GDM_PAM}:"
	nl -ba "${GDM_PAM}" | sed -n '1,120p' | sed -n '1,120p' | egrep -n "auth|pam_selinux_permit|pam_howdy" || true

# Quick “does the module exist and link?”
@howdy-info:
	#!/usr/bin/env bash
	command -v howdy >/dev/null || { echo "howdy not in PATH"; exit 1; }
	howdy --version || true
	test -r /etc/howdy/config.ini && echo "/etc/howdy/config.ini present" || echo "Missing /etc/howdy/config.ini"
