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

This repo ships a `Justfile` with safe helpers for configuring PAM, selecting the Howdy camera, and repairing SELinux policy.

### PAM helpers

- Add Howdy to GDM and / or sudo:

      just howdy-pam-add

- Revert PAM files to the most recent backups:

      just howdy-pam-revert

Every `howdy-pam-add` run makes timestamped backups of the PAM file(s). If the greeter fails:

    Ctrl+Alt+F3
    just howdy-pam-revert
    sudo systemctl restart gdm

**<span style="color:red">To avoid potential lock-out, make sure you verify the changes made to your pam.d config before rebooting</span>**

### Camera helpers

- Interactively test each `/dev/video*` with `howdy test` and pick the right one:

      just howdy-camera-picker

The task will run `sudo howdy test` against each camera node, skip devices that fail, let you keep one or more, and auto-select if only one works.

### SELinux repair

If the SELinux module store gets corrupted (e.g. AVCs show `{ map }` denials for `/dev/video*`), repair and reinstall the Howdy policy in two steps:

1. Mark for a full relabel and reboot:

      just howdy-selinux-repair-start
      sudo reboot

2. After reboot, finish the repair and reinstall the Howdy policy:

      just selinux-repair-finish

This will relabel the SELinux store, rebuild modules, reinstall the `howdy_gdm` policy from the image, and verify it is loaded. It also checks that the `gdm` user is in the `video` group.


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

- **Howdy works for sudo but not GDM login**: it's possible your SELinux policy module store is corrupted. See **SELinux repair,** above

- **Howdy prompts missing**: run `just howdy-pam-add` to (re)insert PAM lines; it will no-op if they’re already present.
