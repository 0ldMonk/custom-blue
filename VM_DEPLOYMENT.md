# Deploying `monk-blue-vm` on Proxmox

`monk-blue-vm` is a bootc/ostree image, not a ready-made cloud disk image —
it has to be converted to a qcow2 before Proxmox can use it, then set up
once as a template so new VMs can be cloned from it.

## 1. Build a qcow2 from the published image

On any Linux box with podman (doesn't have to be the Proxmox host):

```bash
mkdir -p ./output
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --rootfs ext4 \
  ghcr.io/0ldmonk/monk-blue-vm:latest
```

Output lands at `./output/qcow2/disk.qcow2`. The image is public, so no
registry auth is needed.

`--rootfs ext4` is explicit on purpose: `quay.io/fedora/fedora-bootc` doesn't
declare a root filesystem type in its own image config, and
`bootc-image-builder`'s undeclared fallback isn't reliably pinned down —
rather than depend on that, force ext4 directly (confirmed as a real,
supported flag in `bootc-image-builder`'s source,
`bib/cmd/bootc-image-builder/main.go`).

Note: `bootc-image-builder` has its own separate mechanism (a `config.toml`
mounted at `/config.toml`) for baking in a default user at *this* step —
don't use it. The recipe already installs `cloud-init` into the image
itself, so Proxmox's own Cloud-Init drive (step 3) handles the `pi`
user/SSH key at each VM's first boot, same as the rest of the homelab.

## 2. Import the qcow2 into Proxmox

Copy `disk.qcow2` to the Proxmox node, then:

```bash
qm create 9000 --name monk-blue-vm-template --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 disk.qcow2 <your-storage-name>
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

`bootc-image-builder` sizes the root filesystem at its configured minimum
(or 2x the container image size, whichever is larger) — **not** whatever
size you resize the Proxmox virtual disk to. The root volume is LVM
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
