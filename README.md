# Blue-Howdy

Bluefin and Bazzite images with **Howdy face authentication** pre-installed.

This is an alternative to installing Howdy via `rpm-ostree` yourself. These images include Howdy from the [ronnypfannschmidt/howdy-beta](https://copr.fedorainfracloud.org/coprs/ronnypfannschmidt/howdy-beta/) COPR, which provides Fedora 43 support.

---

## Available Images

Images are based on Bluefin and Bazzite variants (Fedora 43 / `stable` only):

- `bluefin-howdy`, `bluefin-dx-howdy`, `bluefin-nvidia-howdy`, `bluefin-dx-nvidia-open-howdy`
- `bazzite-howdy`, `bazzite-dx-howdy`, `bazzite-dx-nvidia-howdy`, `bazzite-dx-nvidia-gnome-howdy`

---

## Disk Images

Pre-built qcow2 and Anaconda ISO images are available for direct download:

**https://images.rosybone.farm**

For example:
- `https://images.rosybone.farm/bluefin-howdy/stable/qcow2/`
- `https://images.rosybone.farm/bluefin-howdy/stable/anaconda-iso/`

Images are rebuilt automatically on every container image update.

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

6. Test with `sudo -k whoami` — Howdy should authenticate via face recognition.

---

## Commands

### Enable/Disable Howdy

```bash
ujust howdy-enable   # Enable Howdy (sudo/polkit)
ujust howdy-disable  # Disable Howdy
ujust howdy-status   # Show current status
```

Howdy is enabled for sudo and polkit only. GDM (login and lock screen) always uses password authentication, which ensures GNOME Keyring auto-unlocks correctly at boot and after suspend.

### Camera Configuration

```bash
ujust howdy-camera-picker
```

Interactively tests each `/dev/video*` device with `howdy test` and lets you pick the right IR camera.

### IR Emitter

Many IR cameras need their emitter explicitly enabled via a UVC control command. The camera picker (`ujust howdy-camera-picker`) detects this automatically — if frames are too dark, it offers to run [linux-enable-ir-emitter](https://github.com/EmixamPP/linux-enable-ir-emitter) to find the correct UVC control, then enables a systemd service to persist it across reboots and suspend/resume.

To manage the IR emitter service separately:

```bash
ujust howdy-ir-enable     # Enable systemd service (activates at boot and after suspend/resume)
ujust howdy-ir-disable    # Disable the service
ujust howdy-ir-status     # Show service status
```

---

## How It Works

Howdy is configured in PAM via `system-auth` only (sudo/polkit), not `password-auth` (GDM). This means:

- **sudo/polkit**: Face authentication via Howdy
- **GDM login and lock screen**: Always password — GNOME Keyring auto-unlocks correctly
- **No suspend/resume workarounds needed** — Howdy never runs during GDM auth

A systemd path unit (`howdy-pam.path`) watches for authselect changes and re-applies the Howdy PAM line automatically, so configuration persists across `authselect select` operations. Works correctly on immutable Fedora variants (Silverblue, Kinoite, etc.).

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

**Howdy not working for sudo**: Run `ujust howdy-enable` to enable authentication.

**Wrong camera selected**: Run `ujust howdy-camera-picker` to select the correct IR camera.

**Upgraded from an older image**: Run `ujust howdy-enable` to clean up stale PAM entries from previous versions (manual PAM editing, howdy-authselect, suspend hooks).

**All frames too dark / IR emitter not working**: Re-run `ujust howdy-camera-picker` — it will detect the dark frames and offer to configure the IR emitter automatically.

**IR emitter stops working after sleep**: Ensure the systemd service is enabled: `ujust howdy-ir-enable`. The service automatically re-runs after every suspend/resume cycle.
