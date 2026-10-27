# Cloud Engineering Command Cheat Sheet

> Quick-reference commands encountered during labs and projects.
>
> These are reference material — not commands that must all be memorised.

## Module 01 — Systems

### Processes

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find a process when I know part of its command/name | `ps aux \| grep '[h]ttp.server'` | Searches the broad process listing for matching command text and avoids the grep process appearing in its own results. |
| Inspect a known process | `ps -p <PID> -o pid,%cpu,%mem,command` | PID, CPU, memory and command. |
| How much physical RAM is a known process currently using? | `ps -p <PID> -o pid,%cpu,%mem,rss,command` | Shows CPU usage, memory percentage, RSS (resident memory), and command for a specific process. |
| Check whether a known PID still exists | `ps -p <PID>` | Whether that process is still present. |
| What is this process's current working directory? | `lsof -a -p <PID> -d cwd` | Shows the current working directory of the specified process. |
| Is a specific process still running, and what state and resources does it have? | `ps -p <PID> -o pid,stat,%cpu,%mem,rss,comm` | Independently checks a known PID and displays its state, CPU usage, resident memory, and command name. Useful when a process disappears from the visible `top` list. |

### CPU / Memory

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| How many logical CPUs are available to this workload? | `nproc` | Reports the number of processing units available to the command's current execution environment. |
| How much RAM is used, free, and available? | `free -h` | Shows human-readable system memory usage, including used, free, cache, available memory, and swap. |
| Which processes are consuming CPU or RAM, and is the system under resource pressure? | `top` | Live view of CPU utilisation, load average, memory availability, process states, and per-process resource usage. Useful for baseline comparisons and recovery validation. |

### Ports / Network Resources

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find what is associated with port 8080 | `lsof -i :8080` | Network resources/processes associated with port 8080. |
| Which network interfaces and IP addresses does this Linux instance have? | `ip -br addr` | Shows a concise list of network interfaces, their states, and assigned IP addresses. Useful for distinguishing loopback (`127.0.0.1`) from private network interfaces. |

### Filesystem / Executables

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| How does my current shell resolve this command name? | `type -a <command>` | Shows matching aliases, functions, builtins, and executables found through `PATH`, where applicable. `-a` displays all matches. |
| Inspect a filesystem entry | `ls -l <path>` | File type, permissions, ownership, size, modification time and symlink target. |
| Does a regular file with this exact name exist somewhere on the filesystem? | `sudo find / -type f -name <name>` | Searches from `/` for regular files matching the exact name. |
| What directories are currently in my shell's command search path? | `echo $PATH` | Displays the ordered, colon-separated directories in the current `PATH`. |
| Temporarily make a directory searchable for commands in this shell environment | `export PATH="/path/to/directory:$PATH"` | Prepends a directory to `PATH` while preserving the existing search path. |
| What directory am I currently working in? | `pwd` | Prints the shell's current working directory. Useful when relative file paths or application launches fail. |
| Does a missing file exist within the relevant application directory? | `find <directory> -type f -name <name>` | Searches a targeted directory tree for a matching regular file. Prefer this before searching the entire filesystem. |

### Environment Variables / Application Configuration

| What am I trying to find out/do? | Command | What it tells me / does |
|---|---|---|
| What exported value is configured for this application variable? | `printenv APP_ENV` | Displays the value of `APP_ENV` in the command's environment. No output can mean the variable is unset or empty. |
| Temporarily configure an environment variable for child processes | `export APP_ENV=development` | Sets and exports `APP_ENV` in the current shell so subsequently launched child processes inherit it. Does not automatically persist across SSH sessions. |

### Service Testing

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Start a tiny local HTTP service | `python3 -m http.server 8080` | Runs Python's built-in HTTP server on port 8080. By default, it listens on all available interfaces. |
| Start an HTTP test server accessible only through IPv4 loopback | `python3 -m http.server 8080 --bind 127.0.0.1` | Starts a temporary HTTP server listening only on `127.0.0.1:8080`. Useful for local application and systemd testing without exposing the listener on the instance's private network interface. |
| Test whether the local HTTP service responds | `curl http://localhost:8080` | Sends an HTTP request to the local service and displays its response. |
| What HTTP status and headers does this endpoint return? | `curl -i <URL>` | Displays the HTTP response headers/status and response body. |
| Can this HTTP endpoint respond to a HEAD request? | `curl -I <URL>` | Requests HTTP response headers without the response body. Useful for checking status codes such as `200 OK`. Some endpoints do not support HEAD requests. |
| Does the local HTTP service respond within a bounded time? | `curl -i --max-time 5 http://127.0.0.1:8080/` | Tests the local HTTP endpoint, including status and headers, with a five-second maximum request duration. Useful for comparing failure and recovery behaviour. |

### Boot / System State

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| How long has this Linux system been running since its most recent boot? | `uptime` | Current time, time since the latest boot, logged-in sessions, and 1/5/15-minute load averages. |
| What process is running as PID 1? | `ps -p 1` | Identifies the PID 1 process; on our Amazon Linux system this was `systemd`. |
| What uniquely identifies the current Linux boot? | `cat /proc/sys/kernel/random/boot_id` | Displays the current boot's unique boot ID. |
| Which systemd units are currently in a failed state? | `systemctl --failed` | Lists units currently recorded as failed. An empty result does not prove that no failures occurred earlier. |
| What error-priority messages occurred during the current boot? | `sudo journalctl -b -p err --no-pager` | Shows journal entries with error priority or higher from the current boot. Useful for boot investigations; not every error indicates an application failure. |

### systemd / Service Management

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| What is the current state of a specific service? | `systemctl status <service>` | Shows the unit's loaded/active state, main process, recent logs, and other runtime information. |
| Which service units are currently running? | `systemctl --type=service --state=running` | Lists service units currently in the running state. |
| What unit configuration is systemd using for this service? | `systemctl cat <service>` | Displays the unit file and associated drop-in configuration files. Useful for inspecting `ExecStart=`, `After=`, `Wants=`, and `WantedBy=`. |
| Make systemd recognise changes to a unit file | `sudo systemctl daemon-reload` | Makes the systemd manager reread unit configurations; does not restart running services. |
| Start or restart a managed service | `sudo systemctl start <service>` / `sudo systemctl restart <service>` | Starts an inactive service or restarts an existing service; useful after changing its configuration. |
| Configure automatic startup after reboot | `sudo systemctl enable <service>` | Creates the configured enablement symlinks; does not immediately start the service. |
| Check whether a service is enabled at boot | `systemctl is-enabled <service>` | Reports the unit's enablement state, independently of whether it is currently running. |
| Investigate recent logs for a specific service | `sudo journalctl -u <service> -n 50 --no-pager` | Displays the latest 50 journal entries associated with the unit, including startup failures and restart attempts. |
| Investigate a service's logs from the current boot | `sudo journalctl -u <service> -b --no-pager` | Shows journal entries associated with the specified service during the current boot. Useful for diagnosing startup failures after reboot. |
| Clear a service's failed state and restart-rate counter | `sudo systemctl reset-failed <service>` | Clears recorded failure state and restart-rate limiting counters, allowing another startup attempt after the underlying issue is fixed. |
| Check whether an application is listening on its expected TCP port | `sudo ss -lntp` | Lists listening TCP sockets with numeric addresses/ports and associated process information where available. |

---

## Module 02 — Linux

### Identity / Groups

| What am I trying to find out/do? | Command | What it tells me / does |
|---|---|---|
| What identity and group memberships does a user have? | `id <user>` | Shows the user's UID, primary GID, and supplementary groups. |
| What members are recorded for a group? | `getent group <group>` | Displays the configured group record and its listed members. |
| Create a new group | `sudo groupadd <group>` | Creates a new Linux group. |
| Create a human user with a home directory | `sudo useradd -m <user>` | Creates the user and creates their home directory. |
| Add an existing user to a supplementary group | `sudo usermod -aG <group> <user>` | Adds the user to the group while preserving their existing supplementary groups. |
| Change a file or directory's group owner | `sudo chgrp <group> <path>` | Changes the group ownership of the specified filesystem object. |
| Start a new shell using a group as the effective/primary group | `newgrp <group>` | Starts a new shell with that group as the effective/primary group. |
| Run one command as another user | `sudo -u <user> <command>` | Executes the specified command using that user's identity; useful for testing access. |

### Permissions / Shared Directories

| What am I trying to find out/do? | Command | What it tells me / does |
|---|---|---|
| Inspect a directory's permissions and ownership | `ls -ld <directory>` | Shows the directory itself rather than listing its contents, including permissions, owner, group, and special permission bits. |
| Add group write permission | `chmod g+w <path>` | `g` = group, `+` = add, `w` = write. |
| Remove group write permission | `chmod g-w <path>` | `g` = group, `-` = remove, `w` = write. The same pattern works with `u/g/o` and `r/w/x`. |
| Make new content inherit a directory's group | `chmod g+s <directory>` | Enables directory setgid so newly created content inherits the directory's group ownership. |

### ACLs

| What am I trying to find out/do? | Command | What it tells me / does |
|---|---|---|
| Inspect a path's access/default ACLs | `getfacl <path>` | Shows ACL entries, ACL masks, defaults, and effective permissions. |
| Configure a default ACL for future content | `setfacl -d -m g:<group>:<permissions> <directory>` | Sets an inheritable group ACL for newly created content inside the directory. |

### Public IP / Access Control

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| What public IPv4 address is my current network using? | `curl -4 ifconfig.me` | Returns the public IPv4 seen externally; useful for checking whether an IP-restricted SSH CIDR such as Terraform `allowed_ssh_cidr` still matches your current connection. |

### Block Devices / Filesystems

| What am I trying to find out/do? | Command | What it tells me / does |
|---|---|---|
| Which block devices exist, and what filesystems are on them? | `lsblk -f` | Lists block devices, filesystem types, UUIDs, and mount points. `-f` includes filesystem information. |
| Does this device already contain filesystem signatures before I format it? | `sudo wipefs -n <device>` | Inspects existing filesystem/RAID signatures without erasing them. `-n` means no changes. |
| What filesystem type and UUID does this block device contain? | `sudo blkid <device>` | Reads filesystem identification metadata, including UUID and type. |
| Which AWS EBS volume corresponds to this NVMe device? | `sudo ebsnvme-id <device>` | On supported EC2 Nitro instances, displays the EBS volume ID and requested attachment name for an EBS NVMe device. |

### Mounts / Persistence / Troubleshooting

| What am I trying to find out/do? | Command | What it tells me / does |
|---|---|---|
| What filesystem is currently mounted at this exact directory? | `findmnt --mountpoint <directory>` | Checks the live mount table for a mount at the exact directory, rather than merely checking that the directory exists. |
| How much filesystem space is available at this path? | `df -h <path>` | Shows the filesystem containing the path and its used/available capacity in human-readable units. |
| What filesystem source is configured for this mount point in `/etc/fstab`? | `findmnt --fstab --target <directory>` | Reads the saved filesystem-table configuration instead of the current live mount state. |
| Is my `/etc/fstab` configuration valid? | `sudo findmnt --verify --verbose` | Checks filesystem-table entries and reports detectable configuration problems. It does not prove that a reboot will succeed. |
| Can Linux mount this filesystem using its `/etc/fstab` entry? | `sudo mount <mountpoint>` | Attempts to mount the filesystem using its saved configuration. Useful after unmounting it safely. |

---

## Module XX — Troubleshooting Toolkit

> Working Checklist

```text
Symptom
   ↓
Evidence
   ↓
Hypothesis
   ↓
Test
   ↓
Root Cause
   ↓
Fix
   ↓
Validation
```

**Core rule:** Do not change the system just because you have observed a symptom. Gather enough evidence to distinguish plausible causes, make the smallest justified change, then validate the behaviour that actually matters.
