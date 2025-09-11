set quiet
set export

# Run command as root if needed

sudoif cmd +args='':
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ $EUID -ne 0 ]]; then
        sudo {{cmd}} {{args}}
    else
        {{cmd}} {{args}}
    fi

# Timestamp helper

ts := `date +%Y%m%d-%H%M%S`

# PAM paths and line to insert

GDM_PAM := "/etc/pam.d/gdm-password"
SDDM_PAM := "/etc/pam.d/sddm"
HOWDY_LINE := "auth sufficient pam_howdy.so"

# Add Howdy to GDM, SDDM and/or sudo; interactive + idempotent
howdy-pam-add:
  #!/usr/bin/env bash
  set -euo pipefail

  GDM_PAM="${GDM_PAM:-/etc/pam.d/gdm-password}"
  SDDM_PAM="${SDDM_PAM:-/etc/pam.d/sddm}"
  HOWDY_LINE="${HOWDY_LINE:-auth sufficient pam_howdy.so}"

  has_gdm=0; [[ -f "$GDM_PAM"  ]] && has_gdm=1
  has_sddm=0; [[ -f "$SDDM_PAM" ]] && has_sddm=1

  insert_pam() {
    local pam_file="$1" label="$2"
    [[ -f "$pam_file" ]] || { echo "Note: $pam_file not found; skipping $label."; return 0; }
    if grep -q 'pam_howdy\.so' "$pam_file"; then
      echo "Howdy already present in $pam_file; skipping."
      return 0
    fi
    just sudoif cp -a "$pam_file" "$pam_file.bak.$(date +%s)"
    tmp="$(mktemp)"
    if grep -q 'pam_selinux_permit\.so' "$pam_file"; then
      awk -v ins="$HOWDY_LINE" '{ print } $0 ~ /pam_selinux_permit\.so/ { print ins }' "$pam_file" > "$tmp"
    else
      awk -v ins="$HOWDY_LINE" 'NR==1 && $0 ~ /^#%PAM-1\.0/ { print; print ins; next } { print }' "$pam_file" > "$tmp"
    fi
    just sudoif install -m 0644 "$tmp" "$pam_file"
    just sudoif restorecon -v "$pam_file" || true
    rm -f "$tmp"
    echo "Inserted Howdy into $pam_file"
  }

  echo "!!! WARNING !!!"
  echo "This modifies PAM. Test the greeter BEFORE rebooting."
  echo "If the greeter fails: Ctrl+Alt+F3 -> login -> 'ujust howdy-pam-revert' -> restart gdm/sddm"
  echo "Proceed? [y/N]: " && read -n 1 -r; echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ $has_gdm -eq 1 ]]; then
      read -p "Add Howdy to login (GDM: $GDM_PAM)? [y/N]: " -n 1 -r; echo
      [[ $REPLY =~ ^[Yy]$ ]] && insert_pam "$GDM_PAM" "GDM"
    fi

    if [[ $has_sddm -eq 1 ]]; then
      read -p "Add Howdy to login (SDDM: $SDDM_PAM)? [y/N]: " -n 1 -r; echo
      [[ $REPLY =~ ^[Yy]$ ]] && insert_pam "$SDDM_PAM" "SDDM"
    fi
  fi

  if [[ -f /etc/pam.d/sudo ]]; then
    read -p "Add Howdy to sudo (/etc/pam.d/sudo)? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      if grep -q 'pam_howdy\.so' /etc/pam.d/sudo; then
        echo "Howdy already present in /etc/pam.d/sudo; skipping."
      else
        just sudoif cp -a /etc/pam.d/sudo "/etc/pam.d/sudo.bak.$(date +%s)"
        awk -v ins="$HOWDY_LINE" 'NR==1 && $0 ~ /^#%PAM-1\.0/ { print; print ins; next } { print }' /etc/pam.d/sudo > /tmp/sudo.new
        just sudoif install -m 0644 /tmp/sudo.new /etc/pam.d/sudo
        just sudoif restorecon -v /etc/pam.d/sudo || true
        rm -f /tmp/sudo.new
        echo "Inserted Howdy into /etc/pam.d/sudo"
      fi
    fi
  fi

  echo
  echo "Done. Now lock your session or switch user to test the greeter."

# Restore most recent backups
howdy-pam-revert:
    #!/usr/bin/env bash
    set -euo pipefail
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
        echo "No backup found for /etc/pam.d/sudo"
    fi
    echo "Done. You may run: sudo systemctl restart gdm or sddm"

@howdy-camera-picker:
    #!/usr/bin/env bash
    set -euo pipefail

    pick_byid() {
        local n="$1"
        local link byid
        link="$(readlink -f "$n" || true)"
        byid="$(ls -l /dev/v4l/by-id/ 2>/dev/null | awk -v t="$link" '$NF==t{print "/dev/v4l/by-id/"$9; exit}')"
        if [ -n "${byid:-}" ]; then printf '%s' "$byid"; else printf '%s' "$n"; fi
    }

    set_device() {
        local path="$1"
        sudo sed -i "s|^#\\?[[:space:]]*device_path[[:space:]]*=.*|device_path = ${path}|" /etc/howdy/config.ini
        grep -E '^[[:space:]]*device_path' /etc/howdy/config.ini || true
    }

    echo "Trying each /dev/video* with howdy test (runs as root)"
    kept_paths=()
    for n in /dev/video*; do
        [ -e "$n" ] || continue
        PATH_TO_USE="$(pick_byid "$n")"
        echo
        echo "=== Testing $PATH_TO_USE ==="
        set_device "$PATH_TO_USE"

        if command -v timeout >/dev/null 2>&1; then
            output="$(sudo timeout 5s howdy test 2>&1 || true)"
        else
            output="$(sudo howdy test 2>&1 || true)"
        fi

        # Skip outright failures
        if echo "$output" | grep -q "Failed to read camera"; then
            echo "Device $PATH_TO_USE not usable; skipping."
            continue
        fi

        # Show preview/log output so the human can judge quality
        echo "$output"
        echo
        read -r -p "Keep this candidate? [y/N/q] " ans
        case "${ans:-n}" in
            y|Y)
                echo "Kept: ${PATH_TO_USE}"
                kept_paths+=("${PATH_TO_USE}")
                ;;
            q|Q)
                echo "Quit requested."
                exit 2
                ;;
            *)
                echo "Skipping ${PATH_TO_USE}"
                ;;
        esac
    done

    case "${#kept_paths[@]}" in
        0)
            echo "No IR device confirmed."
            exit 1
            ;;
        1)
            final="${kept_paths[0]}"
            echo "Only one candidate: $final"
            set_device "$final"
            exit 0
            ;;
        *)
            echo
            echo "Select from kept candidates:"
            i=0
            for p in "${kept_paths[@]}"; do
                printf "  [%d] %s\n" "$i" "$p"
                i=$((i+1))
            done
            read -r -p "Enter number to set as final device: " idx
            if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 0 ] && [ "$idx" -lt "${#kept_paths[@]}" ]; then
                final="${kept_paths[$idx]}"
                echo "Final choice: $final"
                set_device "$final"
                exit 0
            else
                echo "Invalid selection."
                exit 3
            fi
            ;;
    esac

# ---------- SELinux repair & reinstall ----------

@howdy-selinux-repair-start:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Marking system for full SELinux relabel on next boot..."
    if systemctl start selinux-autorelabel-mark.service 2>/dev/null; then
        echo "Queued relabel via selinux-autorelabel-mark.service"
    else
        sudo touch /.autorelabel
        echo "Created /.autorelabel"
    fi
    echo
    echo "Now reboot. After reboot, run:  ujust howdy-selinux-repair-finish"

@howdy-selinux-repair-finish:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "[1/4] Relabel SELinux DB paths (post-reboot hygiene)"
    sudo restorecon -RFv /etc/selinux /var/lib/selinux || true

    echo "[2/4] Rebuild policy module store"
    sudo semodule -B

    echo "[3/4] Reinstall Howdy policy from image source"
    if [[ -x /usr/libexec/howdy-selinux-setup ]]; then
        # If the systemd unit hasn’t been run (e.g. no systemd in container),
        # run the setup script directly to compile and install howdy_gdm.te.
        sudo /usr/libexec/howdy-selinux-setup
    else
        src="/usr/share/selinux/howdy/howdy_gdm.te"
        [ -r "$src" ] || { echo "Missing $src"; exit 1; }
        howdy_selinux="/var/lib/howdy-selinux"
        sudo install -d -m 0755 "$howdy_selinux"
        sudo checkmodule -M -m -o "$howdy_selinux/howdy_gdm.mod" "$src"
        sudo semodule_package -o "$howdy_selinux/howdy_gdm.pp" -m "$howdy_selinux/howdy_gdm.mod"
        sudo semodule -i "$howdy_selinux/howdy_gdm.pp"
    fi

    echo "[4/4] Verify module and basic access"
    sudo semodule -l | grep -qi howdy_gdm || { echo "howdy_gdm still missing"; exit 1; }

    # Add gdm to the video group if necessary, but don’t assume systemd is running.
    if ! id gdm | grep -q 'video'; then
        echo "Adding gdm to video group"
        sudo gpasswd -a gdm video
        if command -v systemctl >/dev/null && systemctl --quiet is-system-running; then
            sudo systemctl restart gdm
        else
            echo "systemd not running; restart gdm manually if required"
        fi
    fi

    ls -Z /dev/video* | sed -n '1,10p' || true
    echo "Done. Try: sudo -u gdm howdy test"