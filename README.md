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

## Quick Start

1. Boot into the image:

```
sudo bootc switch ghcr.io/rall/bluefin-dx-nvidia-open-howdy:gts
```
Other variants exist (`bluefin-howdy`, `bluefin-dx-howdy`, `bluefin-nvidia-howdy`) with `gts` or `latest` tags.

2. Configure PAM (adds Howdy to GDM or SDDM, optional prompt for sudo):

```
ujust howdy-pam-add
```

If the greeter fails after changes:

```
Ctrl+Alt+F3
ujust howdy-pam-revert
sudo systemctl restart gdm or sddm
```

3. Pick the right camera interactively:

```
ujust howdy-camera-picker
```

4. Lock the screen or switch user to test face login at the greeter.

5. If login works with `sudo howdy test` but fails at the greeter, repair SELinux:

```
ujust howdy-selinux-repair-start
sudo reboot
```

After reboot:

```
ujust selinux-repair-finish
```

---

## Configuration

This repo adds Justfile tasks for configuring PAM, selecting the Howdy camera, and repairing SELinux policy.

### PAM helpers

- Add Howdy to the login greeter (GDM or SDDM) and / or sudo:

```
ujust howdy-pam-add
```

- Revert PAM files to the most recent backups:

```
ujust howdy-pam-revert
```

Every `howdy-pam-add` run makes timestamped backups of the PAM file(s). If the greeter fails:

```
Ctrl+Alt+F3
ujust howdy-pam-revert
sudo systemctl restart gdm or sddm
```

**<span style="color:red">To avoid potential lock-out, make sure you verify the changes made to your pam.d config before rebooting</span>**

### Camera helpers

- Interactively test each `/dev/video*` with `howdy test` and pick the right one:

```
ujust howdy-camera-picker
```

The task will run `sudo howdy test` against each camera node, skip devices that fail, let you keep one or more, and auto-select if only one works.

### SELinux repair

If the SELinux module store gets corrupted (e.g. AVCs show `{ map }` denials for `/dev/video*`), repair and reinstall the Howdy policy:

```
ujust howdy-selinux-repair
```

This will relabel the SELinux store, rebuild modules, reinstall the `howdy_gdm` policy from the image, and verify it is loaded.

---

## Development Environment

The repo ships a devcontainer setup with Docker Compose and an [aider](https://aider.chat/) container

---

## Building the Images

Local build and switch with bootc:

```
podman build \
  --build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:gts \
  -t blue-howdy:gts .

sudo bootc switch localhost/blue-howdy:gts
```

---

## Troubleshooting

- **Howdy works for sudo but not at the greeter**: it's possible your SELinux policy module store is corrupted. See **SELinux repair,** above

- **Howdy prompts missing**: run `just howdy-pam-add` to (re)insert PAM lines; it will no-op if they’re already present.

- **Howdy unlocks my session, but I still have to enter my password to unlock the login keyring**: This is expected — PAM doesn't have your password so it can't pass it along to the GNOME Keyring. You could avoid this by blanking the keyring password with [Seahorse](https://wiki.gnome.org/Apps/Seahorse)
