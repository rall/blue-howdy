set quiet

# Enable Howdy authentication (sudo/polkit only — GDM always uses password)
howdy-enable:
    #!/usr/bin/env bash
    set -euo pipefail

    # Remove stale pam_howdy.so lines from pam.d files left over from
    # old manual howdy-pam approach or howdy-authselect
    for pam_file in /etc/pam.d/gdm-password /etc/pam.d/sudo; do
        if [ -f "$pam_file" ] && grep -q 'pam_howdy\.so' "$pam_file"; then
            echo "Removing stale pam_howdy.so from $pam_file"
            sudo sed -i '/pam_howdy\.so/d' "$pam_file"
        fi
    done

    # Remove stale howdy-authselect lines from password-auth (no longer used)
    if [ -f /etc/authselect/password-auth ] && grep -q 'pam_howdy\.so' /etc/authselect/password-auth; then
        echo "Removing pam_howdy.so from password-auth (GDM)"
        sudo sed -i '/pam_howdy\.so/d' /etc/authselect/password-auth
    fi

    # Remove stale session gate from a previous version
    for pam_file in /etc/authselect/password-auth /etc/pam.d/gdm-password; do
        if [ -f "$pam_file" ] && grep -q 'howdy-session-gate' "$pam_file"; then
            echo "Removing stale session gate from $pam_file"
            sudo sed -i '/howdy-session-gate/d' "$pam_file"
        fi
    done

    # Clear stale disabled flag from old suspend hook approach
    if [ -f /etc/howdy/config.ini ] && grep -q '^disabled = true' /etc/howdy/config.ini; then
        echo "Clearing stale disabled flag from Howdy config"
        sudo sed -i '/^disabled = true$/d' /etc/howdy/config.ini
    fi

    # Disable old howdy-authselect path unit if present
    if [ -d /run/systemd/system ] && systemctl is-enabled howdy-authselect.path &>/dev/null; then
        sudo systemctl disable --now howdy-authselect.path || true
    fi

    # Disable old boot-reenable service if present
    if [ -d /run/systemd/system ] && systemctl is-enabled howdy-boot-reenable.service &>/dev/null; then
        sudo systemctl disable --now howdy-boot-reenable.service || true
    fi

    sudo /usr/libexec/howdy-pam enable

    if [ -d /run/systemd/system ]; then
        sudo systemctl enable --now howdy-pam.path
    else
        echo "systemd not running, skipping service enable"
    fi
    echo "Howdy authentication enabled."
    echo "  GDM login/lock:   password (keyring auto-unlocks)"
    echo "  sudo/polkit:      face recognition"

# Disable Howdy authentication
howdy-disable:
    #!/usr/bin/env bash
    set -euo pipefail
    # Remove stale session gate if present (from a previous version)
    for pam_file in /etc/authselect/password-auth /etc/pam.d/gdm-password; do
        if [ -f "$pam_file" ] && grep -q 'howdy-session-gate' "$pam_file"; then
            sudo sed -i '/howdy-session-gate/d' "$pam_file"
        fi
    done
    sudo /usr/libexec/howdy-pam disable
    if [ -d /run/systemd/system ]; then
        sudo systemctl disable --now howdy-pam.path || true
    else
        echo "systemd not running, skipping service disable"
    fi
    echo "Howdy authentication disabled."

# Show Howdy status
howdy-status:
    /usr/libexec/howdy-pam status || true

# Enable IR emitter service (activates at boot and after suspend/resume)
howdy-ir-enable:
    sudo systemctl enable --now linux-enable-ir-emitter.service
    echo "IR emitter service enabled."

# Disable IR emitter service
howdy-ir-disable:
    sudo systemctl disable --now linux-enable-ir-emitter.service
    echo "IR emitter service disabled."

# Show IR emitter service status
howdy-ir-status:
    systemctl status linux-enable-ir-emitter.service || true

@howdy-camera-picker:
    #!/usr/bin/env bash
    set -euo pipefail

    pick_byid() {
        local n="$1"
        local devlinks byid
        devlinks="$(udevadm info --query=property --name="$n" 2>/dev/null | awk -F= '/^DEVLINKS=/{print $2}' || true)"
        for link in $devlinks; do
            if [[ "$link" == /dev/v4l/by-id/* ]]; then
                byid="$link"
                break
            fi
        done
        if [ -n "${byid:-}" ]; then printf '%s' "$byid"; else printf '%s' "$n"; fi
    }

    set_device() {
        local path="$1"
        sudo sed -i "s|^#\?[[:space:]]*device_path[[:space:]]*=.*|device_path = ${path}|" /etc/howdy/config.ini
        # Also store the numeric device id for compatibility
        local id
        id="$(udevadm info --query=property --name="$path" 2>/dev/null | grep -oE '^DEVNAME=/dev/video[0-9]+' | sed 's|^DEVNAME=/dev/video||' | head -n1)"
        if [ -n "${id:-}" ]; then
            sudo sed -i "s|^#\?[[:space:]]*device_id[[:space:]]*=.*|device_id = ${id}|" /etc/howdy/config.ini
        fi
        grep -E '^[[:space:]]*(device_path|device_id)' /etc/howdy/config.ini || true
    }

    echo "Trying each /dev/video* with howdy test (runs as root)"
    kept_paths=()
    ir_configured=false
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

        # Detect dark frames — offer to configure the IR emitter
        if echo "$output" | grep -q "too dark"; then
            echo "$output"
            echo
            if command -v linux-enable-ir-emitter &>/dev/null; then
                read -r -p "Frames too dark — configure IR emitter for this device? [y/N/q] " ir_ans
                case "${ir_ans:-n}" in
                    y|Y)
                        # Resolve /dev/v4l/by-id symlink to /dev/videoN for linux-enable-ir-emitter
                        dev_node="$(readlink -f "$PATH_TO_USE")"
                        echo "Running linux-enable-ir-emitter configure -d $dev_node ..."
                        linux-enable-ir-emitter configure -d "$dev_node" || true
                        echo
                        echo "Retrying howdy test..."
                        set_device "$PATH_TO_USE"
                        if command -v timeout >/dev/null 2>&1; then
                            output="$(sudo timeout 5s howdy test 2>&1 || true)"
                        else
                            output="$(sudo howdy test 2>&1 || true)"
                        fi
                        echo "$output"
                        ir_configured=true
                        ;;
                    q|Q) echo "Quit requested."; exit 2 ;;
                    *)   echo "Skipping $PATH_TO_USE"; continue ;;
                esac
            else
                echo "$output"
            fi
            echo
        else
            echo "$output"
            echo
        fi

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
            else
                echo "Invalid selection."
                exit 3
            fi
            ;;
    esac

    # If the IR emitter was configured during camera picking, offer to enable
    # the systemd service so it persists across reboots and suspend/resume.
    if [ "$ir_configured" = true ]; then
        echo
        if ! systemctl is-enabled linux-enable-ir-emitter.service &>/dev/null; then
            read -r -p "Enable IR emitter service (activates at boot and after suspend)? [Y/n] " svc_ans
            case "${svc_ans:-y}" in
                n|N) echo "Skipped. You can enable later with: ujust howdy-ir-enable" ;;
                *)   sudo systemctl enable --now linux-enable-ir-emitter.service
                     echo "IR emitter service enabled." ;;
            esac
        else
            echo "IR emitter service already enabled."
        fi
    fi
