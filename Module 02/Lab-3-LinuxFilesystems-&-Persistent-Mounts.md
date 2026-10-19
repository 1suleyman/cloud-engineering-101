# Module 02 — Lab 3: Linux Filesystems & Persistent Mounts

## Business Problem

Bob’s Burger needed additional persistent storage on its Linux EC2 server to hold application data separately from the root filesystem.

The storage needed to remain accessible after instance reboots, use a reliable filesystem identifier, and support safe diagnosis and recovery when mount configurations failed.

## What I Built

- Provisioned and attached a separate **5 GiB AWS EBS volume** to an Amazon Linux 2023 EC2 instance using Terraform.
- Identified the attached EBS volume and its corresponding Linux NVMe block device.
- Inspected the block device before formatting to confirm that no existing filesystem signatures were present.
- Created an **XFS filesystem** directly on the additional block device.
- Created `/mnt/app-data` as the application-data mount point.
- Mounted the filesystem and verified its capacity, filesystem type, and active mount state.
- Wrote and retrieved a test file to confirm that data was accessible through the mounted filesystem.
- Configured `/etc/fstab` using the filesystem UUID to make the mount persistent across reboots.
- Validated the persistent mount configuration, tested remounting through `/etc/fstab`, and confirmed successful mounting after reboot.
- Introduced a controlled incorrect-UUID fault, diagnosed the failure using system evidence, restored a known-good configuration, and validated recovery without data loss.

## Storage Architecture

The additional storage was configured as follows:

```text
AWS EC2 Instance
│
├── Root EBS Volume
│   └── /dev/nvme0n1
│       └── /dev/nvme0n1p1
│           └── XFS
│               └── /
│
└── Application Data EBS Volume (5 GiB)
    └── /dev/nvme1n1
        └── XFS filesystem
            └── /mnt/app-data
                └── storage-test.txt
```

### EBS Volume and Linux Block Device

AWS EBS provides block storage that can be attached to an EC2 instance.

On this Nitro-based EC2 instance, the additional volume appeared as:

```text
/dev/nvme1n1
```

Although Terraform requested the attachment name `/dev/sdh`, Linux exposed the volume using an NVMe device name.

I verified the mapping using:

```bash
sudo ebsnvme-id /dev/nvme1n1
```

This command displays the AWS EBS volume ID and its requested attachment device name, helping distinguish the intended volume from other disks.

### Filesystem Creation

Before creating a filesystem, I inspected the available block devices:

```bash
lsblk -f
```

This displays block devices and their filesystem information, including filesystem types, UUIDs, and mount points.

I also checked for existing filesystem signatures:

```bash
sudo wipefs -n /dev/nvme1n1
sudo blkid -p /dev/nvme1n1
```

- `wipefs -n` performs a read-only inspection of filesystem signatures without erasing them.
- `blkid -p` probes the block device for filesystem metadata.

Neither command identified an existing filesystem signature on the new volume.

After confirming that the device was the intended disposable EBS volume, I created an XFS filesystem:

```bash
sudo mkfs.xfs /dev/nvme1n1
```

This formats the selected block device with XFS.

The filesystem was created directly on the whole block device rather than on a separate partition.

**XFS** provides the filesystem structures needed to organise files and directories on the underlying block storage.

Formatting is potentially destructive, so identifying and inspecting the correct device before running `mkfs.xfs` was an important safety requirement.

## Mount Configuration

### Mount Point

I created the application-data directory:

```bash
sudo mkdir -p /mnt/app-data
```

The `-p` option creates missing parent directories when needed and does not fail merely because the target directory already exists.

I then mounted the XFS filesystem:

```bash
sudo mount /dev/nvme1n1 /mnt/app-data
```

This associates the filesystem on the block device with `/mnt/app-data`, making its contents accessible through the Linux directory tree.

### Mount Verification

I checked the active mount:

```bash
findmnt /mnt/app-data
```

This reads the current mount information and identifies the filesystem mounted at the specified path.

The result confirmed:

```text
TARGET         SOURCE        FSTYPE
/mnt/app-data  /dev/nvme1n1  xfs
```

I also checked the filesystem capacity:

```bash
df -h /mnt/app-data
```

The `-h` option displays storage sizes in human-readable units.

The output confirmed approximately **5 GiB of filesystem capacity** mounted at `/mnt/app-data`.

### Data-Write Verification

I created a test file:

```bash
echo "Bob's Burger storage test" | sudo tee /mnt/app-data/storage-test.txt
```

`tee` writes the supplied text to the target file with administrator privileges.

This was necessary because the mounted filesystem's root directory was owned by `root`, so the normal `ec2-user` account could not create files there directly.

I then read the file:

```bash
cat /mnt/app-data/storage-test.txt
```

`cat` displays the file's contents.

The result was:

```text
Bob's Burger storage test
```

Because the directory was confirmed as an active mount from `/dev/nvme1n1`, this demonstrated that the test file was written to and read from the additional filesystem.

## Persistent Mount Configuration

A manual mount does not automatically guarantee that the filesystem will be mounted again after reboot.

I configured `/etc/fstab`, the Linux filesystem table, to define the persistent mount.

### Filesystem UUID

I identified the filesystem UUID using:

```bash
sudo blkid /dev/nvme1n1
```

`blkid` identifies filesystem metadata, including the filesystem type and UUID.

I used the filesystem UUID rather than `/dev/nvme1n1` because Linux NVMe device names can change when devices are enumerated.

A filesystem UUID normally remains stable across reboots, although recreating or deliberately modifying the filesystem UUID can change it.

### `/etc/fstab` Entry

Before modifying the configuration, I created a backup:

```bash
sudo cp -a /etc/fstab /etc/fstab.bak
```

The `-a` option preserves file attributes such as permissions, ownership, and timestamps.

I added the following entry:

```fstab
UUID=181c97b9-b9fe-45ba-8299-3fde4ccc7e7e /mnt/app-data xfs defaults 0 0
```

The six fields define:

| Field | Purpose |
|---|---|
| `UUID=...` | Identifies the filesystem to mount |
| `/mnt/app-data` | Specifies the mount point |
| `xfs` | Specifies the filesystem type |
| `defaults` | Applies standard mount options |
| `0` | Excludes the filesystem from the legacy `dump` backup mechanism |
| `0` | Disables traditional boot-time `fsck` checking through this field |

This configuration allows Linux to re-establish the application-data mount during startup.

### Configuration Validation

I validated the filesystem table:

```bash
sudo findmnt --verify --verbose
```

This checks `/etc/fstab` entries and reports configuration problems, including unresolved filesystem sources and missing mount targets.

The output confirmed:

```text
UUID=181c97b9-b9fe-45ba-8299-3fde4ccc7e7e translated to /dev/nvme1n1
source /dev/nvme1n1 exists
FS type is xfs

Success, no errors or warnings detected
```

### Remount Verification

To verify that Linux could mount the filesystem using `/etc/fstab`, I ran:

```bash
sudo systemctl daemon-reload
sudo umount /mnt/app-data
sudo mount /mnt/app-data
```

- `systemctl daemon-reload` refreshes systemd configuration, including mount units generated from `/etc/fstab`.
- `umount` detaches the filesystem without deleting its stored data.
- `mount /mnt/app-data` looks up the target in `/etc/fstab` and uses its configured filesystem source and options.

This differs from manually specifying both the device and mount point, because it tests whether the saved configuration can successfully establish the mount.

The filesystem mounted successfully, and the original test file remained readable.

### Reboot Persistence Verification

I rebooted the EC2 instance and reconnected.

After startup, I verified the filesystem using:

```bash
findmnt /mnt/app-data
df -h /mnt/app-data
cat /mnt/app-data/storage-test.txt
```

These commands checked the active mount, filesystem capacity, and original test-file contents.

The filesystem was mounted at `/mnt/app-data`, approximately 5 GiB of capacity was available, and the test file remained accessible.

This demonstrated that the persistent mount configuration worked across a reboot.

## Troubleshooting & Recovery

### Symptom

I introduced a controlled fault by changing the final character of the application-data filesystem UUID in `/etc/fstab`.

The actual filesystem UUID ended in:

```text
...7e7e
```

The faulty configuration referenced:

```text
...7e7f
```

After unmounting the filesystem, I attempted to mount it again using the configured mount point:

```bash
sudo mount /mnt/app-data
```

This command uses the `/etc/fstab` entry associated with the specified mount point.

Linux returned:

```text
mount: /mnt/app-data: can't find UUID=181c97b9-b9fe-45ba-8299-3fde4ccc7e7f.
```

### Evidence

Before triggering the failure, I compared the filesystem's actual UUID, the configured UUID, and the current mount state.

```bash
sudo blkid /dev/nvme1n1
sudo findmnt --fstab --target /mnt/app-data
findmnt /mnt/app-data
```

- `blkid` identified the actual filesystem UUID.
- `findmnt --fstab --target` displayed the UUID configured in `/etc/fstab`.
- `findmnt` without `--fstab` checked the current mount state.

The evidence showed that the actual filesystem UUID ended in `e`, while the configured UUID ended in `f`.

The filesystem initially remained mounted despite the incorrect configuration because changing `/etc/fstab` does not automatically remove an existing mount.

### Root Cause

The application-data entry in `/etc/fstab` referenced a UUID that did not exist on the attached filesystem.

Linux therefore could not resolve the configured filesystem source when attempting a new mount.

**The filesystem itself was healthy.** The error was caused by an incorrect configuration reference, not damaged filesystem metadata or lost data.

### Recovery

Before introducing the fault, I had preserved the complete working configuration:

```bash
sudo cp -a /etc/fstab /etc/fstab.lab3.good
```

This created a known-good backup while preserving file attributes.

I restored it using:

```bash
sudo cp -a /etc/fstab.lab3.good /etc/fstab
```

I then validated and refreshed the configuration:

```bash
sudo findmnt --verify --verbose
sudo systemctl daemon-reload
```

The filesystem table passed validation with no errors or warnings.

Finally, I mounted the filesystem again:

```bash
sudo mount /mnt/app-data
```

The mount succeeded.

### Validation

I confirmed the restored mount and tested data accessibility:

```bash
findmnt /mnt/app-data
cat /mnt/app-data/storage-test.txt
```

The active mount showed:

```text
/mnt/app-data /dev/nvme1n1 xfs
```

The original file still contained:

```text
Bob's Burger storage test
```

This demonstrated that:

- the correct filesystem configuration had been restored;
- Linux could resolve the correct UUID;
- the XFS filesystem could be mounted again;
- the original data remained accessible;
- recovery did not require reformatting the filesystem or replacing the EBS volume.

The incident was resolved without rebooting the EC2 instance.

## Production Considerations

### Stable Filesystem Identification

Using filesystem UUIDs in `/etc/fstab` reduces dependence on Linux device enumeration.

A device name such as `/dev/nvme1n1` may change, while the filesystem UUID normally remains stable unless the filesystem is recreated or its UUID is explicitly modified.

### Safe Filesystem Changes

Formatting the wrong block device can destroy existing data.

Before formatting, an engineer should verify the intended EBS volume, inspect existing filesystem signatures, and establish whether any existing data must be preserved.

### Safe `/etc/fstab` Changes

Incorrect mount configuration can prevent filesystems from mounting and may affect system startup.

Changes should therefore be backed up, validated, and tested before rebooting.

For the controlled fault exercise, I kept the root and EFI filesystem entries unchanged and avoided rebooting while the configuration was deliberately incorrect.

### `nofail` and Application Safety

The `nofail` mount option can allow normal system startup to continue when a secondary filesystem is unavailable.

However, `nofail` does not guarantee that applications depending on that filesystem will behave safely.

If `/mnt/app-data` exists but the EBS filesystem is not mounted, an application could accidentally write data to the underlying root filesystem.

For an application that requires the data volume, startup should depend on the required filesystem being mounted.

For a systemd-managed service, `RequiresMountsFor=/mnt/app-data` can establish dependencies on the mounts needed to access that path.

The decision to use `nofail` should depend on whether the filesystem is essential to system operation, how the application handles unavailable storage, and the desired recovery behaviour.

The lab demonstrated the `defaults` configuration. The `nofail` option and application-level mount dependency were discussed as production design considerations rather than implemented.

## Lessons Learned

- AWS EBS provides block storage, which Linux exposes through block devices.
- A filesystem such as XFS organises files and directories on storage, while mounting makes that filesystem accessible through a directory.
- Filesystems can be created directly on a whole block device without requiring a separate partition.
- Formatting must only be performed after verifying the correct device and checking for existing data.
- `lsblk`, `blkid`, `findmnt`, and `df` provide different forms of storage evidence and should be selected according to the troubleshooting question.
- Manual mounts do not guarantee persistence across reboots; `/etc/fstab` provides the configuration for re-establishing mounts.
- Filesystem UUIDs provide more reliable persistent references than Linux NVMe device names.
- A valid `/etc/fstab` entry should be checked both through configuration validation and an actual mount test.
- A filesystem can remain mounted even when its saved `/etc/fstab` configuration is incorrect.
- An incorrect filesystem UUID in `/etc/fstab` does not itself damage the filesystem or its data.
- Troubleshooting should follow symptom → evidence → hypothesis → test → root cause → fix → validation.
- Restoring a verified configuration backup reduces the risk of introducing further errors during incident recovery.
- `nofail` addresses system startup behaviour, while separate application dependencies are needed to prevent unsafe operation without required storage.

## Project Status

**Complete .** 
Additional EBS storage, XFS filesystem creation, mounting, data-write verification, persistent configuration, reboot validation, controlled UUID failure, root-cause diagnosis, and recovery were demonstrated successfully.
