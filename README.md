# Blue-Howdy

Bluefin and Bazzite images with **Howdy face authentication** pre-installed.

This is an alternative to installing Howdy via `rpm-ostree` yourself. These images include Howdy from the [ronnypfannschmidt/howdy-beta](https://copr.fedorainfracloud.org/coprs/ronnypfannschmidt/howdy-beta/) COPR, which provides Fedora 43 support and seamless authselect integration.

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

6. Lock your session or switch user to test.

---

## Commands

### Enable/Disable Howdy

```bash
ujust howdy-enable   # Enable Howdy (lock screen + sudo; boot login uses password)
ujust howdy-disable  # Disable Howdy
ujust howdy-status   # Show current status
```

On a fresh boot, GDM always prompts for your password so that GNOME Keyring gets unlocked. Once you're logged in, Howdy handles lock-screen unlock and sudo via face recognition.

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

A session gate (`/usr/libexec/howdy-session-gate`) is inserted before `pam_howdy.so` in `password-auth` so that Howdy is skipped when gnome-keyring needs a password: on fresh boot (no active session) and on the first lock-screen unlock after suspend/resume (a systemd sleep hook sets a marker). The `system-auth` file is not gated, so sudo and polkit always use face recognition.

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

**System shuts down after suspend/resume when logging in**: After resume, Howdy authenticates without a password, but gnome-keyring needs one to re-establish its session — this crashes GDM. A systemd sleep hook automatically skips Howdy on the first lock-screen unlock after resume, forcing password entry so gnome-keyring works correctly. Sudo and polkit are unaffected and always use face authentication. If you also upgraded from an older image that used manual PAM editing (`ujust howdy-pam`), stale `pam_howdy.so` lines may remain in `/etc/pam.d/gdm-password` or `/etc/pam.d/sudo` — run `ujust howdy-enable` to clean those up.

**Howdy unlocks session but keyring still needs password**: This is expected. PAM doesn't have your password so it can't unlock the GNOME Keyring. You can blank the keyring password with [Seahorse](https://wiki.gnome.org/Apps/Seahorse) if desired.
