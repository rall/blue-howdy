# Blue-Howdy

Bluefin images that enable **Howdy face login** out of the box, with **SELinux enforcing**.

---

## What these images do

- Based on Bluefin (plain, dx, nvidia, nvidia-open; `gts`/`latest`).
- Ship Howdy for biometric authentication at the display manager.
- Include SELinux tooling and install a custom module on first boot:
  - Grants `gdm_t`, `xdm_t`, `sddm_t`, `lightdm_t` access to `/dev/video*`.
  - Compiles policy from a raw `.te` at boot.
  - Falls back to AVC-derived module if install fails.
  - **Never** sets domains to permissive.
- A systemd unit (`howdy-selinux-install.service`) runs the helper at boot.

---

## PAM Configuration

To actually use Howdy, PAM must be updated:

- **GDM login**: edit `/etc/pam.d/gdm-password` and add:

      auth sufficient pam_howdy.so

  right after `pam_selinux_permit.so`.

- **Sudo** (optional): add the same line at the top of `/etc/pam.d/sudo`.

**Warning:** Always test Howdy at the GNOME greeter **before rebooting**.  
If it fails, switch to a TTY (Ctrl+Alt+F3), log in with your password, and revert.

---

## Justfile Tasks

This repo includes a `Justfile` with safe helpers for PAM:

- Show status of PAM files:

      just pam-status

- Add Howdy to GDM only:

      just pam-add

- Add Howdy to GDM + sudo:

      just pam-add howdy_in_sudo=1

- Revert to most recent backups:

      just pam-revert

Every `pam-add` run makes a timestamped backup of the PAM file. If the greeter fails, you can revert quickly:

    Ctrl+Alt+F3
    just pam-revert
    sudo systemctl restart gdm

---

## GNOME Keyring Note

Howdy unlocks your session, but GNOME Keyring still requires your password to unlock the login keyring. This is expected — PAM never had a password to pass along.

Options:
- Accept the prompt (secure default).
- Blank the keyring password in Seahorse (less secure).

---

## Development Environment

The repo ships a devcontainer setup with Docker Compose and an aider container

---

## Building the Images

Local build and switch with bootc:

    podman build \
      --build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:gts \
      -t blue-howdy:gts .

    sudo bootc switch localhost/blue-howdy:gts

---

## Troubleshooting

- **Policy install fails** (`semodule: policy store corrupt`):

      sudo systemctl start selinux-autorelabel-mark.service || sudo touch /sysroot/.autorelabel
      sudo reboot
      sudo restorecon -RFv /etc/selinux /var/lib/selinux
      sudo semodule -B

- **Camera blocked at greeter**:  
  Ensure `/dev/video*` is labeled `video_device_t`:

      ls -Z /dev/video*
      restorecon -v /dev/video*

- **Howdy prompts missing**: rerun `just pam-status` to confirm PAM lines are present.

