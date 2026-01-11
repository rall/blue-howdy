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

# Enable Howdy authentication via authselect
howdy-enable:
    just sudoif howdy-authselect enable
    @echo "Howdy authentication enabled. Lock your session or switch user to test."

# Disable Howdy authentication via authselect
howdy-disable:
    just sudoif howdy-authselect disable
    @echo "Howdy authentication disabled."

# Show Howdy authselect status
howdy-status:
    howdy-authselect status || true

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
