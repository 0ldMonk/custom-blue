# custom-blue &nbsp; [![bluebuild build badge](https://github.com/0ldmonk/custom-blue/actions/workflows/build.yml/badge.svg)](https://github.com/0ldmonk/custom-blue/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/0ldmonk/monk-blue-nvidia-gnome:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/0ldmonk/monk-blue-nvidia-gnome:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## Installer ISOs & VM disk image

The [`disk-images`](.github/workflows/disk-images.yml) workflow runs every ~3 days
(and on manual dispatch), building with
[`bootc-image-builder`](https://github.com/osbuild/bootc-image-builder) from each
image's `:latest` tag and publishing to a single rolling GitHub release tagged
[`images-latest`](../../releases/tag/images-latest) (assets overwritten each run):

- `<image>-installer.iso.xz` — Anaconda **installer** ISO for every image
  (`monk-blue-nvidia-gnome`, `monk-blue-nvidia-cosmic`, `monk-blue-vm`). Boot a
  blank machine/VM from it to install onto disk (these are installers, not
  live-desktop ISOs).
- `monk-blue-vm.qcow2` — VM only. Directly bootable: import as a Proxmox disk or
  template; user/SSH/hostname come from Cloud-Init, not the image.

Every artifact ships a `.md5` sidecar. Anything over GitHub's 2 GiB per-asset cap
(the desktop ISOs) is split into `<name>.part00`, `.part01`, … pieces you
reassemble after download.

### Download & assemble

```bash
# 1. from the release page, download every .partNN (or the single file if it
#    wasn't split) plus the matching .md5:
#    https://github.com/0ldmonk/custom-blue/releases/tag/images-latest

# 2. reassemble — skip if there are no .partNN files (artifact wasn't split):
cat monk-blue-nvidia-gnome-installer.iso.xz.part* > monk-blue-nvidia-gnome-installer.iso.xz

# 3. verify integrity:
md5sum -c monk-blue-nvidia-gnome-installer.iso.xz.md5

# 4. decompress the ISO before use (the qcow2 needs no decompression):
unxz monk-blue-nvidia-gnome-installer.iso.xz
```

> [!NOTE]
> Hosting these on Releases is within GitHub's terms — they're the repo's own
> build outputs (Releases' intended use), and the rolling tag overwrites old
> assets each run so total storage stays bounded, rather than accumulating as
> bulk file storage.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/0ldmonk/monk-blue-nvidia-gnome
```
