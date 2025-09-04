set shell := ["bash", "-euo", "pipefail", "-c"]
# Export all assignment variables into the recipe environment
set export

# -------- Helpers --------

# Run command as root if needed
sudoif cmd +args='':
    @if [[ $EUID -ne 0 ]]; then sudo {{cmd}} {{args}}; else {{cmd}} {{args}}; fi

# Timestamp helper
ts := `date +%Y%m%d-%H%M%S`

# PAM paths and line to insert
GDM_PAM := "/etc/pam.d/gdm-password"
HOWDY_LINE := "auth sufficient pam_howdy.so"

# -------- Apply / Revert --------

# Add Howdy to GDM and/or sudo; interactive, idempotent, with backups
howdy-pam-add:
    echo "!!! WARNING !!!"
    echo "This modifies PAM. TEST GNOME LOGIN AT THE GREETER BEFORE REBOOTING."
    echo "If the greeter fails: Ctrl+Alt+F3 -> login -> 'ujust howdy-pam-revert' -> 'sudo systemctl restart gdm'"

    # --- GDM (interactive, no-op if already present) ---
    read -p "Add Howdy to GDM login ({{GDM_PAM}})? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      if grep -q 'pam_howdy\.so' "{{GDM_PAM}}"; then
        echo "Howdy already present in {{GDM_PAM}}; skipping."
      else
        just sudoif cp -a "{{GDM_PAM}}" "{{GDM_PAM}}.bak.{{ts}}"
        if grep -q 'pam_selinux_permit\.so' "{{GDM_PAM}}"; then
          awk -v ins='{{HOWDY_LINE}}' '
            { print }
            $0 ~ /pam_selinux_permit\.so/ { print ins }
          ' "{{GDM_PAM}}" > /tmp/gdm-password.new
        else
          awk -v ins='{{HOWDY_LINE}}' '
            BEGIN { print ins }
            { print }
          ' "{{GDM_PAM}}" > /tmp/gdm-password.new
        fi
        just sudoif install -m 0644 /tmp/gdm-password.new "{{GDM_PAM}}"
        just sudoif restorecon -v "{{GDM_PAM}}" || true
        just sudoif restorecon -v "{{GDM_PAM}}" || true
        rm -f /tmp/gdm-password.new
        echo "Inserted Howdy into {{GDM_PAM}}"
      fi
    fi

    # --- sudo (interactive, no-op if already present) ---
    if [[ -f /etc/pam.d/sudo ]]; then
      read -p "Also add Howdy to sudo (/etc/pam.d/sudo)? [y/N]: " -n 1 -r; echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        if grep -q 'pam_howdy\.so' /etc/pam.d/sudo; then
          echo "Howdy already present in /etc/pam.d/sudo; skipping."
        else
          just sudoif cp -a /etc/pam.d/sudo "/etc/pam.d/sudo.bak.{{ts}}"
          awk -v ins='${HOWDY_LINE}' '
          NR==1 && $0 ~ /^#%PAM-1\.0/ { print; print ins; next }
          { print }
          ' "${GDM_PAM}" > /tmp/gdm-password.new
          just sudoif install -m 0644 /tmp/sudo.new /etc/pam.d/sudo
          just sudoif restorecon -v /etc/pam.d/sudo || true
          just sudoif restorecon -v /etc/pam.d/sudo || true
          rm -f /tmp/sudo.new
          echo "Inserted Howdy into /etc/pam.d/sudo"
        fi
      fi
    fi

    echo
    echo "Now lock your session or switch user to test the greeter BEFORE rebooting."

# Restore most recent backups
howdy-pam-revert:
    echo "Restoring most recent PAM backups (if any)..."
    latest_gdm="$(ls -1t {{GDM_PAM}}.bak.* 2>/dev/null | head -n1 || true)"
    if [[ -n "${latest_gdm}" ]]; then
      echo "Restoring ${latest_gdm} -> {{GDM_PAM}}"
      just sudoif install -m 0644 "${latest_gdm}" "{{GDM_PAM}}"
    else
      echo "No backup found for {{GDM_PAM}}"
    fi
    latest_sudo="$(ls -1t /etc/pam.d/sudo.bak.* 2>/dev/null | head -n1 || true)"
    if [[ -n "${latest_sudo}" ]]; then
      echo "Restoring ${latest_sudo} -> /etc/pam.d/sudo"
      just sudoif install -m 0644 "${latest_sudo}" /etc/pam.d/sudo
    else
      echo "No backup found for /etc/pam.d/sudo (that’s fine if you didn’t add it)"
    fi
    echo "Done. You may run: sudo systemctl restart gdm"

# -------- Camera helpers --------

# list candidate V4L devices (stable by-id paths)
howdy-detect:
    @ls -l /dev/v4l/by-id/ 2>/dev/null | awk '{print $$9, "->", $$11}' || echo "no /dev/v4l/by-id entries"

# show devices which probably support IR
howdy-ir-candidates:
    @for n in /dev/video*; do \
        prod="$$(udevadm info -n $$n | sed -n 's/^E: ID_V4L_PRODUCT=//p')"; \
        fmts="$$(v4l2-ctl -d $$n --list-formats-ext 2>/dev/null \
            | awk '/^\t\t\[/ {p=1} p {print}' \
            | tr -s " " \
            | cut -d: -f2- \
            | tr "\n" " ")"; \
        ir_name=0; mono_only=0; \
        printf "%s  product:\"%s\"  fmts: %s\n" "$$n" "$$prod" "$$fmts"; \
        printf "%s" "$$prod" | grep -qiE "(^|[[:space:]])IR([[:space:]]|$$)" && ir_name=1; \
        printf "%s" "$$fmts" | grep -qiE "(^|[[:space:]])(GREY|Y8|Y10|Y12)([[:space:]]|$$)" && mono_only=1; \
        if [ "$$ir_name" -eq 1 ] || [ "$$mono_only" -eq 1 ]; then \
            hint=""; \
            [ "$$ir_name" -eq 1 ] && hint="$$hint[IR-name]"; \

# autopick the first by-id path that looks like IR (name says IR or only mono formats)
howdy-pick-ir:
    @best=""; \
    for n in /dev/video*; do \
        prod="$$(udevadm info -n $$n | sed -n 's/^E: ID_V4L_PRODUCT=//p')"; \
        fmts="$$(v4l2-ctl -d $$n --list-formats-ext 2>/dev/null \
            | awk '/^\t\t\[/ {p=1} p {print}' \
            | tr -s " " \
            | cut -d: -f2- \
            | tr "\n" " ")"; \
        if printf "%s" "$$prod" | grep -qiE "(^|[[:space:]])IR([[:space:]]|$$)"; then \
            best="$$n"; \
            break; \
        fi; \
        if printf "%s" "$$fmts" | grep -qiE "(^|[[:space:]])(GREY|Y8|Y10|Y12)([[:space:]]|$$)"; then \
            if ! printf "%s" "$$fmts" | grep -qiE "(^|[[:space:]])(MJPG|YUYV|RGB)([[:space:]]|$$)"; then \
                best="$$n"; \
            fi; \
        fi; \
    done; \
    test -n "$$best" || { echo "No obvious IR device found"; exit 1; }; \
    link="$$(readlink -f "$$best")"; \
    byid="$$(ls -l /dev/v4l/by-id/ 2>/dev/null | awk -v t="$$link" '$$NF==t{print "/dev/v4l/by-id/"$$9; exit}')"; \
    path="$${byid:-$$best}"; \
    echo "Setting Howdy device to $$path"; \
    sudo sed -i "s|^#\\?\\s*device_path\\s*=.*|device_path = $$path|" /etc/howdy/config.ini; \
    grep -E '^\\s*device_path' /etc/howdy/config.ini
