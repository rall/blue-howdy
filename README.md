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

## Configuration

### PAM
To actually use Howdy, PAM must be updated:

- **GDM login**: edit `/etc/pam.d/gdm-password` and add:

      auth sufficient pam_howdy.so

  right after `pam_selinux_permit.so`.

- **Sudo** (optional): add the same line at the top of `/etc/pam.d/sudo`.

**Warning:** Always test Howdy at the GNOME greeter **before rebooting**.  
If it fails, switch to a TTY (Ctrl+Alt+F3), log in with your password, and revert.


### Set camera device

```bash
just howdy-detect              # list stable by-id camera paths
just howdy-ir-candidates       # see likely IR nodes
just howdy-pick-ir             # auto-pick and set device_path
```

If your hardware presents IR and RGB as one multi-function node with mixed formats, the heuristic might need nudging. In that case, pick the right /dev/v4l/by-id/...-video-indexX manually from howdy-ir-candidates and set it with:

`device_path = /dev/v4l/by-id/<whatever>-video-index0  # set this in /etc/howdy/config.ini`

---

## Justfile Tasks

This repo includes a `Justfile` with helpers to safely configure PAM and set Howdy’s camera:

- Add Howdy to GDM (optional prompt to add to sudo as well):

      just howdy-pam-add

- Revert PAM files to the most recent backups:

      just howdy-pam-revert

- List stable camera paths:

      just howdy-detect

- Show likely IR-capable video devices:

      just howdy-ir-candidates

- Auto-pick and set Howdy’s device_path:

      just howdy-pick-ir

Every `howdy-pam-add` run makes a timestamped backup of the PAM file(s). If the greeter fails, you can revert quickly:

    Ctrl+Alt+F3
    just howdy-pam-revert
    sudo systemctl restart gdm

---

## GNOME Keyring Note

Howdy unlocks your session, but GNOME Keyring still requires your password to unlock the login keyring. This is expected — PAM never had a password to pass along.

Options:
- Accept the prompt (secure default).
- Blank the keyring password in Seahorse (less secure).

---

## Development Environment

The repo ships a devcontainer setup with Docker Compose and an [aider](https://aider.chat/) container

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

- **Howdy prompts missing**: run `just howdy-pam-add` to (re)insert PAM lines; it will no-op if they’re already present.

