# Deploying `monk-blue-vm` on Proxmox

`monk-blue-vm` is a bootc/ostree image, but a ready-to-boot qcow2 is built
from it automatically — download that, then set it up once as a Proxmox
template so new VMs can be cloned from it.

## 1. Download the qcow2

The [`disk-images`](.github/workflows/disk-images.yml) workflow rebuilds it
every ~3 days from `monk-blue-vm:latest` and publishes it to the rolling
[`images-latest`](../../releases/tag/images-latest) release. It's over
GitHub's 2 GiB per-asset cap, so it ships split into `.partNN` pieces with
one `.md5` covering the reassembled file:

```bash
gh release download images-latest --repo 0ldmonk/custom-blue \
  --pattern 'monk-blue-vm.qcow2*'
cat monk-blue-vm.qcow2.part* > monk-blue-vm.qcow2
md5sum -c monk-blue-vm.qcow2.md5
rm monk-blue-vm.qcow2.part*
```

The release is public — no `gh auth`/registry login needed; the assets can
equally be downloaded from the release page in a browser. No decompression
step: unlike the ISOs, the qcow2 is not xz'd.

Nothing machine-specific is baked in. `bootc-image-builder` has its own
mechanism (a `config.toml`) for creating a default user at build time and
the workflow deliberately doesn't use it — the recipe installs `cloud-init`
into the image instead, so Proxmox's Cloud-Init drive (step 3) handles the
`pi` user/SSH key at each VM's first boot, same as the rest of the homelab.

To build one locally instead (custom root size, or a tag other than
`latest`), copy the podman invocation out of `.github/workflows/disk-images.yml`
— it carries the non-obvious flags (`--rootfs ext4` because
`quay.io/fedora/fedora-bootc` declares no root filesystem type, and the
`minsize` config without which the root partition is too small to boot).

## 2. Import the qcow2 into Proxmox

Copy `monk-blue-vm.qcow2` to the Proxmox node (or just run step 1 there),
then:

```bash
qm create 9000 --name monk-blue-vm-template --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 monk-blue-vm.qcow2 <your-storage-name>
qm set 9000 --scsihw virtio-scsi-pci --scsi0 <your-storage-name>:vm-9000-disk-0
qm set 9000 --boot order=scsi0
```

(`<your-storage-name>` is whatever storage pool you use, e.g. `local-lvm`.)

## 3. Attach a Cloud-Init drive and set `pi`

This is what actually populates the `pi` account that the image's baked-in
`/etc/sudoers.d/pi` (passwordless sudo) is waiting for:

```bash
qm set 9000 --ide2 <your-storage-name>:cloudinit
qm set 9000 --ciuser pi --sshkeys ~/.ssh/your_vm_key.pub
qm set 9000 --ipconfig0 ip=dhcp   # or static, matching your network
```

SSH password auth is disabled repo-wide in the image
(`PasswordAuthentication no`, `PermitRootLogin no`) — key-only access via
whatever key you set here.

## 4. Template it

```bash
qm template 9000
```

Then, per actual VM:

```bash
qm clone 9000 <newvmid> --name <hostname>
```

Each clone can override `--ciuser` / `--sshkeys` / `--ipconfig0`
independently in its own Cloud-Init tab.

## 5. Growing the disk

The published qcow2's root filesystem is 15 GiB (the `minsize` the workflow
passes to `bootc-image-builder`) — **not** whatever size you resize the
Proxmox virtual disk to. The root volume is LVM
(PV -> VG -> LV), and cloud-init's `growpart` module does not grow logical
volumes, only partitions — so `qm resize` alone does not get you more
usable space. Full chain, after `qm resize <vmid> scsi0 +20G`:

```bash
growpart /dev/sda 3          # grows the partition (cloud-init does this part automatically)
pvresize /dev/sda3           # grow the LVM physical volume
lvextend -l +100%FREE /dev/mapper/<vg>-root
resize2fs /dev/mapper/<vg>-root   # ext4 -- see --rootfs ext4 above
```

Confirm with `df -h` after. Partition/VG names will vary — check with
`lsblk` first.

- `systemctl status qemu-guest-agent` should be active — this is what lets
  Proxmox report the VM's IP and do graceful shutdown/reboot from its UI.
- Monitoring (`node-exporter`) is installed but not configured or enabled —
  that's owned by the homelab Ansible repo, same as the rest of the fleet.

## Updating an already-deployed VM

Rebasing/updating this VM works the same as any bootc/ostree system:

```bash
bootc upgrade   # or: rpm-ostree upgrade, depending on which is present
```

New recipe changes take effect on the next scheduled build + your next
upgrade — no need to re-image or re-clone existing VMs.
