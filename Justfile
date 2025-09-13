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
    echo "Marking system for full SELinux relabel on next boot..."
    systemctl start selinux-autorelabel-mark.service || echo "systemctl not available"
  }

  echo "!!! WARNING !!!"
  echo "This modifies PAM. Test the greeter BEFORE rebooting."
  echo "If the greeter fails: Ctrl+Alt+F3 -> login -> 'ujust howdy-pam-revert' -> restart gdm/sddm"
  printf "Proceed? [y/N]: " && read -n 1 -r; echo
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

  echo "Done. Now lock your session or switch user to test the greeter."

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

@howdy-selinux-repair:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "[1/3] Relabel SELinux DB paths (post-reboot hygiene)"
    sudo restorecon -RFv /etc/selinux /var/lib/selinux || true
    sudo semodule -B

    echo "[2/3] Compile/install Howdy policy"
    HS=/var/lib/howdy-selinux
    sudo install -d -m 0755 "$HS"
    cd "$HS"
    sudo /usr/libexec/howdy-selinux-setup || true
    if [ ! -f howdy_gdm_auto.pp ]; then
        SRC=/usr/share/selinux/howdy/howdy_gdm.te
        [ -r "$SRC" ]
        sudo checkmodule -M -m -o howdy_gdm.mod "$SRC"
        sudo semodule_package -o howdy_gdm_auto.pp -m howdy_gdm.mod
    fi
    sudo semodule -i howdy_gdm_auto.pp

    echo "[3/3] Verify module"
    sudo semodule -l | grep -qi howdy_gdm || { echo "howdy_gdm missing"; exit 1; }

    echo "Done. Try: sudo -u gdm howdy test"
