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

# Add Howdy to GDM, SDDM and/or sudo; interactive, idempotent, with backups
howdy-pam-add:
	#!/usr/bin/env bash
	set -euo pipefail

	# Defaults so the mustache-y placeholders don't leak into runtime
	GDM_PAM="${GDM_PAM:-/etc/pam.d/gdm-password}"
	SDDM_PAM="${SDDM_PAM:-/etc/pam.d/sddm}"
	HOWDY_LINE="${HOWDY_LINE:-auth sufficient pam_howdy.so}"

	# Non-interactive controls for CI:
	#   HOWDY_PAM_YES=1 -> skip "Proceed?" and treat targets via *_GDM/SDDM/SUDO
	#   HOWDY_PAM_GDM=1|0, HOWDY_PAM_SDDM=1|0, HOWDY_PAM_SUDO=1|0
	HOWDY_PAM_YES="${HOWDY_PAM_YES:-0}"
	HOWDY_PAM_GDM="${HOWDY_PAM_GDM:-0}"
	HOWDY_PAM_SDDM="${HOWDY_PAM_SDDM:-0}"
	HOWDY_PAM_SUDO="${HOWDY_PAM_SUDO:-0}"

	has_gdm=0;   [[ -f "$GDM_PAM"  ]] && has_gdm=1
	has_sddm=0;  [[ -f "$SDDM_PAM" ]] && has_sddm=1

	if [[ $has_gdm -eq 0 && $has_sddm -eq 0 ]]; then
	  echo "Note: neither $GDM_PAM nor $SDDM_PAM found; skipping greeter integration."
	fi

	echo "!!! WARNING !!!"
	echo "This modifies PAM. TEST LOGIN AT THE GREETER BEFORE REBOOTING."
	echo "If the greeter fails: Ctrl+Alt+F3 -> login -> 'ujust howdy-pam-revert' -> restart gdm/sddm"

	prompt_yn() {
	  local prompt="$1"
	  if [[ "$HOWDY_PAM_YES" == "1" ]]; then
	    # CI mode: the caller will set *_GDM/SDDM/SUDO to decide per-target
	    echo "$prompt [auto]" 1>&2
	    REPLY="y"
	    return 0
	  fi
	  if [[ -t 0 ]]; then
	    read -p "$prompt" -n 1 -r; echo
	  else
	    # no TTY: read from stdin (so printf pipeline works)
	    printf "%s" "$prompt" 1>&2
	    IFS= read -r REPLY || REPLY=""
	    [[ -n "$REPLY" ]] && REPLY="${REPLY:0:1}"
	    echo 1>&2
	  fi
	}

	insert_pam() {
	  local pam_file="$1"
	  local label="$2"
	  local want="${3:-ask}"

	  if [[ "$want" == "ask" ]]; then
	    prompt_yn "Add Howdy to login (${label}: ${pam_file})? [y/N]: "
	    [[ ! "$REPLY" =~ ^[Yy]$ ]] && return 0
	  elif [[ "$want" == "no" ]]; then
	    return 0
	  fi

	  if grep -q 'pam_howdy\.so' "$pam_file"; then
	    echo "Howdy already present in $pam_file; skipping."
	    return 0
	  fi

	  just sudoif cp -a "$pam_file" "$pam_file.bak.$(date +%s)"
	  tmpfile="$(mktemp)"
	  if grep -q 'pam_selinux_permit\.so' "$pam_file"; then
	    awk -v ins="$HOWDY_LINE" '{ print } $0 ~ /pam_selinux_permit\.so/ { print ins }' "$pam_file" > "$tmpfile"
	  else
	    awk -v ins="$HOWDY_LINE" 'NR==1 && $0 ~ /^#%PAM-1\.0/ { print; print ins; next } { print }' "$pam_file" > "$tmpfile"
	  fi
	  just sudoif install -m 0644 "$tmpfile" "$pam_file"
	  just sudoif restorecon -v "$pam_file" || true
	  rm -f "$tmpfile"
	  echo "Inserted Howdy into $pam_file"
	}

	# Greeters
	if [[ $has_gdm -eq 1 ]];  then
	  choice="ask"; [[ "$HOWDY_PAM_YES" == "1" ]] && choice=$([[ "$HOWDY_PAM_GDM" == "1" ]] && echo yes || echo no)
	  insert_pam "$GDM_PAM" "GDM" "$choice"
	fi

	if [[ $has_sddm -eq 1 ]]; then
	  choice="ask"; [[ "$HOWDY_PAM_YES" == "1" ]] && choice=$([[ "$HOWDY_PAM_SDDM" == "1" ]] && echo yes || echo no)
	  insert_pam "$SDDM_PAM" "SDDM" "$choice"
	fi

	# sudo
	if [[ -f /etc/pam.d/sudo ]]; then
	  if [[ "$HOWDY_PAM_YES" == "1" ]]; then
	    choice=$([[ "$HOWDY_PAM_SUDO" == "1" ]] && echo yes || echo no)
	  else
	    prompt_yn "Also add Howdy to sudo (/etc/pam.d/sudo)? [y/N]: "
	    choice=$([[ "$REPLY" =~ ^[Yy]$ ]] && echo yes || echo no)
	  fi
	  if [[ "$choice" == "yes" && ! $(grep -q 'pam_howdy\.so' /etc/pam.d/sudo; echo $?) -eq 0 ]]; then
	    just sudoif cp -a /etc/pam.d/sudo "/etc/pam.d/sudo.bak.$(date +%s)"
	    awk -v ins="$HOWDY_LINE" 'NR==1 && $0 ~ /^#%PAM-1\.0/ { print; print ins; next } { print }' /etc/pam.d/sudo > /tmp/sudo.new
	    just sudoif install -m 0644 /tmp/sudo.new /etc/pam.d/sudo
	    just sudoif restorecon -v /etc/pam.d/sudo || true
	    rm -f /tmp/sudo.new
	    echo "Inserted Howdy into /etc/pam.d/sudo"
	  fi
	fi

	echo
	echo "Now lock your session or switch user to test the greeter BEFORE rebooting."

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
    src="/usr/share/selinux/howdy/howdy_gdm.te"
    [ -r "$src" ] || { echo "Missing $src"; exit 1; }
    howdy-selinux="/var/lib/howdy-selinux"
    sudo install -d -m 0755 "$howdy-selinux"
    sudo checkmodule -M -m -o "$howdy-selinux/howdy_gdm.mod" "$src"
    sudo semodule_package -o "$howdy-selinux/howdy_gdm.pp" -m "$howdy-selinux/howdy_gdm.mod"
    sudo semodule -i "$howdy-selinux/howdy_gdm.pp"

    echo "[4/4] Verify module and basic access"
    sudo semodule -l | grep -qi howdy_gdm || { echo "howdy_gdm still missing"; exit 1; }
    id gdm | grep -q 'video' || { echo "Adding gdm to video group"; sudo gpasswd -a gdm video; sudo systemctl restart gdm; }
    ls -Z /dev/video* | sed -n '1,10p' || true
    echo "Done. Try: sudo -u gdm howdy test"
