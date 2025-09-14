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

Other variants exist (`bluefin-howdy`, `bluefin-dx-howdy`, `bluefin-nvidia-howdy`) with `gts` or `stable` tags.

2. Configure PAM (adds Howdy to GDM or SDDM, optional prompt for sudo):

```
ujust howdy-pam
```

3. Pick the right camera interactively:

```
ujust howdy-camera-picker
```

4. Reboot.

---

## Configuration

This repo adds Justfile tasks for configuring PAM, selecting the Howdy camera, and repairing SELinux policy.

### PAM helpers

- Add or remove Howdy to/from the login greeter (GDM or SDDM) and/or sudo:

```
ujust howdy-pam
```

**<span style="color:red">To avoid potential lock-out, make sure you verify the changes made to your pam.d config before rebooting</span>**

### Camera helpers

- Interactively test each `/dev/video*` with `howdy test` and pick the right one:

```
ujust howdy-camera-picker
```

The task will run `sudo howdy test` against each camera node, skip devices that fail, let you keep one or more, and auto-select if only one works.

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

- **Howdy prompts missing**: run `just howdy-pam` to (re)insert PAM lines; it will no-op if they’re already present.

- **Howdy unlocks my session, but I still have to enter my password to unlock the login keyring**: This is expected — PAM doesn't have your password so it can't pass it along to the GNOME Keyring. You could avoid this by blanking the keyring password with [Seahorse](https://wiki.gnome.org/Apps/Seahorse)
