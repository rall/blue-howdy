# Blue-Howdy

Bluefin and Bazzite images with **Howdy face authentication** pre-installed.

This is an alternative to installing Howdy via `rpm-ostree` yourself. These images include Howdy from the [ronnypfannschmidt/howdy-beta](https://copr.fedorainfracloud.org/coprs/ronnypfannschmidt/howdy-beta/) COPR, which provides Fedora 43 support and seamless authselect integration.

---

## Available Images

Images are based on Bluefin and Bazzite variants (Fedora 43 / `stable` only):

- `bluefin-howdy`, `bluefin-dx-howdy`, `bluefin-nvidia-howdy`, `bluefin-dx-nvidia-open-howdy`
- `bazzite-howdy`, `bazzite-dx-howdy`, `bazzite-dx-nvidia-howdy`, `bazzite-dx-nvidia-gnome-howdy`

---

## Quick Start

1. Switch to the image:

```bash
sudo bootc switch ghcr.io/rall/bluefin-dx-nvidia-open-howdy:stable
```

2. Reboot.

3. Enable Howdy authentication:

```bash
ujust howdy-enable
```

4. Pick the right camera:

```bash
ujust howdy-camera-picker
```

5. Add your face:

```bash
sudo howdy add
```

6. Lock your session or switch user to test.

---

## Commands

### Enable/Disable Howdy

```bash
ujust howdy-enable   # Enable Howdy for login and sudo
ujust howdy-disable  # Disable Howdy
ujust howdy-status   # Show current status
```

### Camera Configuration

```bash
ujust howdy-camera-picker
```

Interactively tests each `/dev/video*` device with `howdy test` and lets you pick the right IR camera.

---

## How It Works

These images use `howdy-authselect` from the ronnypfannschmidt COPR, which configures PAM via authselect. This is more robust than manual PAM file editing because:

- Configuration persists across `authselect select` operations
- No manual SELinux policy rebuilds needed
- Works correctly on immutable Fedora variants (Silverblue, Kinoite, etc.)

---

## Building Locally

```bash
podman build \
  --build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable \
  -t blue-howdy:stable .

sudo bootc switch localhost/blue-howdy:stable
```

---

## Troubleshooting

**Howdy not prompting at login**: Run `ujust howdy-enable` to enable authentication.

**Wrong camera selected**: Run `ujust howdy-camera-picker` to select the correct IR camera.

**Howdy unlocks session but keyring still needs password**: This is expected. PAM doesn't have your password so it can't unlock the GNOME Keyring. You can blank the keyring password with [Seahorse](https://wiki.gnome.org/Apps/Seahorse) if desired.
