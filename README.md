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

After the helper finishes, review the PAM files it manages—`/etc/pam.d/gdm-password` or `/etc/pam.d/sddm` (whichever display manager you chose) and `/etc/pam.d/sudo` if you opted into sudo prompts; these are the only PAM configs the helper ever modifies—to make sure the Howdy line looks right before you reboot. It will quietly skip whichever of those files you left disabled or are missing on your system.

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

After `ujust howdy-pam` runs, inspect each PAM file you enabled to confirm the helper inserted (or removed) `auth sufficient pam_howdy.so` in the right place. The helper only ever works with these hardcoded paths—picking either the GDM or SDDM config based on your selection and touching `/etc/pam.d/sudo` only if you enabled sudo integration—skipping any that are disabled or missing:

- `/etc/pam.d/gdm-password` (GDM login; sometimes referenced as `/etc/pam.d/gdp-password`)
- `/etc/pam.d/sddm` (SDDM login)
- `/etc/pam.d/sudo` (sudo prompts)

#### Example PAM edits

The snippets below show what the Howdy line looks like before and after the helper runs. Distributions can vary slightly, so treat these as guides and make sure your files match the "after" pattern where relevant. If you later re-run the helper and decline one of the prompts, it will remove the Howdy line to restore the "before" state.

**/etc/pam.d/gdm-password** (GDM login; sometimes documented as `/etc/pam.d/gdp-password`)

Before:

```
#%PAM-1.0
auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
auth     requisite      pam_nologin.so
auth     required       pam_env.so
auth     substack       password-auth
auth     optional       pam_gnome_keyring.so
...
```

After:

```
#%PAM-1.0
auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
auth sufficient pam_howdy.so
auth     requisite      pam_nologin.so
auth     required       pam_env.so
auth     substack       password-auth
auth     optional       pam_gnome_keyring.so
...
```

**/etc/pam.d/sddm**

Before:

```
#%PAM-1.0
auth     include        system-login
auth     optional       pam_kwallet5.so
auth     optional       pam_gnome_keyring.so
...
```

After:

```
#%PAM-1.0
auth sufficient pam_howdy.so
auth     include        system-login
auth     optional       pam_kwallet5.so
auth     optional       pam_gnome_keyring.so
...
```

**/etc/pam.d/sudo**

Before:

```
#%PAM-1.0
auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth
```

After:

```
#%PAM-1.0
auth sufficient pam_howdy.so
auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth
```

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
