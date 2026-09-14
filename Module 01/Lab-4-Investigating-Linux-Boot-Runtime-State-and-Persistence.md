# Module 01 — Lab 4: Investigating Linux Boot, Runtime State, and Persistence

## Business Problem

Bob's Burger Corporation wants its junior cloud engineers to understand what actually happens when a Linux server boots and reboots rather than treating a successful SSH connection as proof that everything started correctly.

The task was to provision a disposable Amazon Linux EC2 instance, connect to it over SSH, gather operating-system evidence about the current boot and running services, deliberately reboot the server, and determine which parts of the system **persisted across the reboot** and which parts were **recreated as runtime state**.

The investigation used multiple independent sources of evidence, including system uptime, PID 1, systemd state, running services, the Linux boot ID, a persistent test file, and the SSH service.

---

## Project Goal

Build an evidence-based mental model connecting:

```text
Power / Boot
      ↓
UEFI
      ↓
Bootloader
      ↓
Linux kernel on storage
      ↓
Kernel loaded into RAM
      ↓
Control transferred to kernel
      ↓
Userspace starts
      ↓
systemd runs as PID 1
      ↓
Services and processes
```

Then use a controlled reboot to prove the distinction between:

```text
Persistent state
      vs
Runtime / boot-specific state
```

---

# Infrastructure Setup

## Provision the Linux Server

The lab used a disposable **Amazon Linux 2023 EC2 instance** provisioned with Terraform.

The infrastructure included:

* Amazon Linux 2023 EC2 instance
* `t3.small` instance type
* Existing EC2 key pair
* Security group permitting SSH
* Public IPv4 connectivity
* Terraform-managed infrastructure

Before connecting, the SSH security-group source was restricted to the public IPv4 address being used for the connection with a `/32` CIDR.

### Engineering Lesson

A `/32` IPv4 CIDR represents exactly one IPv4 address.

Conceptually:

```text
<public-ip>/32
       ↓
All 32 IPv4 bits fixed
       ↓
One exact IPv4 address
```

This allowed SSH access from the required public IPv4 rather than unnecessarily opening TCP port `22` to a larger address range.

---

## Connect over SSH

The instance was accessed using SSH with the local private key:

```bash
ssh -i mainkey.pem ec2-user@<public-dns>
```

### Command Recognition

| Part           | Meaning                               |
| -------------- | ------------------------------------- |
| `ssh`          | SSH client                            |
| `-i`           | Specify the identity/private-key file |
| `mainkey.pem`  | Local private key                     |
| `ec2-user`     | Remote Amazon Linux user              |
| `<public-dns>` | Public hostname of the EC2 instance   |

The corresponding public key was available to the EC2 instance for authentication.

The private key remained on the client machine.

### SSH Mental Model

```text
NETWORK ACCESS
Public DNS
    ↓
EC2 public IPv4
    ↓
Security Group
    ↓
TCP/22 permitted?
    ↓
SSH connection can reach server

AUTHENTICATION
Local private key
    ↕ cryptographic proof
Matching public key on EC2
    ↓
Identity authenticated
```

Network reachability therefore had to succeed **before** SSH authentication could take place.

---

# Investigation

## Establish Boot Evidence with `uptime`

I first inspected how long the Linux system had been running:

```bash
uptime
```

Observed:

```text
15:19:12 up 3 min, 1 user, load average: 0.28, 0.21, 0.10
```

### Interpretation

| Field              | Meaning                                 |
| ------------------ | --------------------------------------- |
| `15:19:12`         | Current system time                     |
| `up 3 min`         | Time since the most recent boot         |
| `1 user`           | One logged-in user session              |
| `0.28, 0.21, 0.10` | Load averages over 1, 5, and 15 minutes |

The important boot evidence was:

```text
up 3 min
```

This showed that the Linux system had been running for approximately three minutes since its **most recent boot**.

---

## Inspect PID 1

I then investigated the first userspace process:

```bash
ps -p 1
```

Observed:

```text
PID TTY          TIME CMD
  1 ?        00:00:02 systemd
```

This showed:

```text
PID 1 → systemd
```

### Important Precision

The Linux kernel itself is **not PID 1**.

At the level required for this lab:

```text
Kernel takes control
        ↓
Kernel initializes the system
        ↓
Kernel starts the initial userspace process
        ↓
systemd runs as PID 1
```

`systemd` is the Linux system and service manager used by this system.

The operating system should also not be thought of as one large process. The running system consists of the kernel plus userspace processes and other runtime state.

### `ps` Output Precision

The `TIME` value:

```text
00:00:02
```

represented CPU time consumed by the process rather than the total elapsed time that the process had existed.

---

## Check the Overall systemd State

I asked systemd for the overall operational state of the system:

```bash
systemctl is-system-running
```

Observed:

```text
running
```

This did **not** simply mean:

> "The systemd process exists."

Instead, systemd was reporting that the system had reached its normal operational state.

This also did not mean that every possible service on the machine had to be running. Services can legitimately be inactive, stopped, or not intended to run continuously.

---

## Inspect Running Services

I inspected service units currently in the running state:

```bash
systemctl --type=service --state=running
```

The output included services such as:

```text
UNIT                         LOAD    ACTIVE SUB       DESCRIPTION

amazon-ssm-agent.service     loaded  active running   amazon-ssm-agent
auditd.service               loaded  active running   Security Auditing Service
chronyd.service              loaded  active running   NTP client/server
containerd.service           loaded  active running   containerd container runtime
docker.service               loaded  active running   Docker Application Container Engine
sshd.service                 loaded  active running   OpenSSH server daemon
systemd-journald.service     loaded  active running   Journal Service
systemd-logind.service       loaded  active running   User Login Management
systemd-networkd.service     loaded  active running   Network Configuration
systemd-resolved.service     loaded  active running   Network Name Resolution
```

This provided evidence that userspace services had been brought up after boot.

---

## Understanding systemd Service State

A representative line was:

```text
UNIT          LOAD     ACTIVE     SUB       DESCRIPTION
sshd.service  loaded   active     running   OpenSSH server daemon
```

### Interpretation

**UNIT**

```text
sshd.service
```

is the **systemd unit name**, not simply a process name.

A `.service` unit provides systemd with information for managing a service.

---

**LOAD**

```text
loaded
```

means systemd successfully loaded the unit's definition/configuration and understands how that unit should be managed.

It does **not** mean:

> "The application's process has been loaded from storage into RAM."

---

**ACTIVE**

```text
active
```

is the unit's high-level activation state.

---

**SUB**

```text
running
```

is the more specific, unit-type-dependent state.

For this service:

```text
ACTIVE → active
SUB    → running
```

---

## Active vs Enabled

The investigation also exposed an important distinction:

```text
ACTIVE / RUNNING
        ↓
What is the service's state right now?

ENABLED
        ↓
Is systemd configured to start the service
through the appropriate startup/boot dependencies?
```

A service being enabled does not guarantee that it will successfully be running after boot.

Similarly, a service can currently be running without necessarily being enabled for automatic startup.

---

# Service Units and Processes

A key discovery during the lab was that a **service is not the same thing as a process**.

Conceptually:

```text
systemd
   ↓ manages
service unit
   ↓
processes associated with the service
```

A service can have a main process and potentially additional processes.

Therefore:

> **A service unit does not itself have a PID in the same sense that a process does.**

Instead, systemd can identify the service's **main process** and its PID.

This distinction became directly observable later when inspecting `sshd.service`.

---

# Capturing a Unique Boot Identifier

`uptime` provided useful evidence about the current boot, but I wanted evidence capable of distinguishing one boot from another.

Linux exposes a boot-specific identifier:

```bash
cat /proc/sys/kernel/random/boot_id
```

Before rebooting, the instance returned:

```text
7e5f673d-d0bf-422d-bd44-ec0be376bd92
```

This was recorded as the identifier for that particular boot.

---

## `/proc` and Live Kernel State

The path:

```text
/proc/sys/kernel/random/boot_id
```

introduced an important Linux concept.

`/proc` is a **virtual filesystem exposed by the running kernel**. Despite its name originating from process information, it exposes more than just processes.

For this lab, the useful mental model was:

```text
/proc
   ↓
live information exposed by the running kernel
   ↓
/proc/sys/kernel/random/boot_id
   ↓
identifier associated with the current boot
```

This should not be treated like an ordinary persistent file stored on disk.

---

# Controlled Reboot

## Form a Hypothesis

Before rebooting, I predicted:

> The current `boot_id` should be replaced with a different identifier after the system completes a new boot.

The server was then deliberately rebooted from Linux:

```bash
sudo reboot
```

The existing SSH connection was terminated while the operating system rebooted.

After the instance became reachable again, I established a new SSH connection.

---

# Validate the New Boot

## Check Uptime Again

After reconnecting:

```bash
uptime
```

Observed:

```text
15:27:36 up 3 min, 1 user, load average: 0.00, 0.01, 0.00
```

The low uptime provided evidence that the system had recently completed another boot.

---

## Compare the Boot Identifier

The boot ID was queried again:

```bash
cat /proc/sys/kernel/random/boot_id
```

The identifier was different from the one recorded before reboot.

The experiment therefore established:

```text
BOOT A
boot_id = 7e5f673d-...
        ↓
      REBOOT
        ↓
BOOT B
boot_id = different identifier
```

This provided stronger evidence for distinguishing individual boots than relying on PID 1 alone.

---

# Persistent Storage Experiment

## Create a Test File

To investigate persistence across reboot, I created a file:

```bash
echo "I survived the reboot" > ~/boot-test.txt
```

I verified its contents:

```bash
cat ~/boot-test.txt
```

Observed:

```text
I survived the reboot
```

The file existed under the user's home directory on the EC2 instance's persistent root filesystem.

---

## Predict What Will Survive

Before the next reboot, two different types of state were available for comparison:

```text
boot-test.txt
→ file on persistent storage

boot_id
→ boot-specific kernel state
```

The server was rebooted again.

---

## Validate Persistent vs Boot-Specific State

After reconnecting:

```bash
cat ~/boot-test.txt
```

Observed:

```text
I survived the reboot
```

The file had survived.

I then queried:

```bash
cat /proc/sys/kernel/random/boot_id
```

Observed:

```text
a39dad2b-626c-4692-bbc4-a38d813b0c73
```

The boot ID had changed again.

This demonstrated the central distinction:

```text
PERSISTENT STORAGE                  BOOT / RUNTIME STATE

boot-test.txt                       boot_id
      │                                │
      │ reboot                         │ reboot
      ▼                                ▼
still exists ✅                    changes ✅
```

---

# Persistent State vs Runtime State

This experiment corrected an important misconception.

A reboot does **not** normally erase files stored on the instance's persistent EBS-backed filesystem.

Instead:

```text
PERSISTENT STATE                    RUNTIME STATE
(on storage)                        (running system)

programs                            processes
configuration                       memory contents
persistent files                    network connections
service definitions                 current boot state
                                    boot_id
                                    other changing runtime state
```

A process is therefore **one example of runtime state**, rather than runtime state meaning only "a process."

For example:

```text
Python executable on storage
          ↓
       execute
          ↓
Python process at runtime
```

After reboot:

```text
Python executable → remains on persistent storage
old Python process → no longer exists
```

---

# EBS Persistence vs Filesystem Mount Persistence

The lab also exposed a separate storage misconception.

A filesystem's **data surviving on an EBS volume** and a filesystem being **automatically mounted after reboot** are different questions.

Conceptually:

```text
EBS volume
    ↓
persistent data
    ↓
data can survive reboot
```

Whereas a manually mounted filesystem may require persistent mount configuration to be automatically mounted again during later boots.

The deeper mechanics involving tools and configuration such as:

```text
mkfs
mount
/etc/fstab
```

were deliberately deferred because they were outside the immediate boot-process learning objective.

---

# Prove PID 1 Was Recreated

After another reboot, I inspected PID 1 again:

```bash
ps -p 1
```

Observed:

```text
PID TTY          TIME CMD
  1 ?        00:00:00 systemd
```

At first glance, this could appear to show that the original systemd process had survived because it still had PID `1`.

That conclusion would be incorrect.

The correct model is:

```text
BOOT A
systemd process A
PID 1
     ↓
   REBOOT
     ↓
BOOT B
systemd process B
PID 1
```

The PID was **reused**.

The process itself did not survive the reboot.

### Engineering Lesson

A PID identifies a process instance within the context of a running system at a point in time.

Therefore:

```text
same PID across different boots
            ≠
same process instance
```

The different `boot_id` values established that these PID 1 observations belonged to different boots.

---

# Inspect the SSH Service After Reboot

I then inspected the SSH service:

```bash
systemctl status sshd
```

Observed:

```text
Loaded: loaded (/usr/lib/systemd/system/sshd.service; enabled; preset: enabled)

Active: active (running) since Mon 2026-09-14 06:37:38 UTC

Main PID: 1915 (sshd)

CGroup: /system.slice/sshd.service
        └─1915 "sshd: /usr/sbin/sshd -D [listener] ..."
```

The journal entries also showed:

```text
systemd[1]: Starting sshd.service - OpenSSH server daemon...
sshd[1915]: Server listening on 0.0.0.0 port 22.
sshd[1915]: Server listening on :: port 22.
systemd[1]: Started sshd.service - OpenSSH server daemon.
```

This provided direct evidence that systemd had started the SSH service during the new boot.

---

## Main PID Does Not Mean "Service PID"

The output:

```text
Main PID: 1915 (sshd)
```

does not mean:

> "The SSH service has PID 1915."

A more precise statement is:

> **The SSH service's main process had PID `1915`.**

Conceptually:

```text
sshd.service
     │
     ├── Main process
     │      └── PID 1915
     │
     └── potentially additional associated processes
```

This reinforces the distinction between a **systemd service unit** and the **running processes associated with it**.

---

# Prove the SSH Runtime Was Recreated

The SSH status provided a particularly useful causal sequence:

```text
REBOOT
   ↓
old runtime ends
   ↓
new Linux boot
   ↓
systemd runs as PID 1
   ↓
systemd starts sshd.service
   ↓
new sshd main process created
   ↓
sshd listens on TCP/22
   ↓
new SSH connection accepted
```

Therefore, the old SSH process did not survive the reboot.

The persistent SSH program, configuration, and systemd unit definition remained available on storage, allowing systemd to create a **new running SSH process** during the new boot.

---

# Linux Boot Mental Model

The complete high-level model established during the lab was:

```text
Power
  ↓
UEFI firmware
  ↓
Bootloader
  ↓
Locate Linux kernel on storage
  ↓
Load kernel into RAM
  ↓
Transfer control to kernel
  ↓
Kernel initializes the system
  ↓
Kernel starts initial userspace process
  ↓
systemd runs as PID 1
  ↓
systemd brings up/manages configured units
  ↓
services and associated processes
  ↓
operational Linux system
```

This is intentionally a high-level model. Lower-level firmware, kernel initialization, initramfs, systemd dependency resolution, and other boot internals were outside the required depth of this lab.

---

# Live-System Mental Model

The lab connected persistent system components with runtime state:

```text
             PERSISTENT STORAGE
                     │
        ┌────────────┼────────────┐
        ↓            ↓            ↓
     Kernel       Programs     Configuration
        │            │            │
        └────────────┼────────────┘
                     ↓
                   BOOT
                     ↓
              Kernel running
                     ↓
                systemd PID 1
                     ↓
                Service units
                     ↓
                  Processes
                     ↓
          ┌──────────┼──────────┐
          ↓          ↓          ↓
        CPU        Memory    Network state
                                ↓
                         sshd listens :22

                     ↓
                   REBOOT
                     ↓
          old runtime state ends
                     ↓
          persistent storage remains
                     ↓
            new runtime created
```

---

# Engineering Lessons Learned

## 1. Boot Success Should Be Established from Evidence

A successful SSH connection is useful evidence, but this lab deliberately collected several independent observations:

```text
uptime
        ↓
time since latest boot

ps -p 1
        ↓
systemd running as PID 1

systemctl is-system-running
        ↓
system reached operational state

running service units
        ↓
userspace services available

boot_id
        ↓
identity of the current boot
```

Multiple observations provide a stronger system picture than relying on a single command.

---

## 2. Persistent State and Runtime State Are Different

Persistent files and programs can remain available across reboot.

Running processes and other runtime state do not simply continue through a reboot.

Instead:

```text
persistent definitions/data
          ↓
       new boot
          ↓
new runtime instances created
```

---

## 3. A Program Is Not Its Running Process

The SSH executable and configuration persisted on storage.

The old `sshd` process did not.

After reboot, systemd used persistent system configuration to start a **new process instance**.

This reinforces the program/process distinction established in earlier Module 01 labs.

---

## 4. A Service Is Not a Process

A systemd service unit represents something systemd manages.

That service can have a main process and potentially additional associated processes.

Therefore:

```text
service unit
     ≠
process
```

This distinction is important when interpreting tools such as:

```bash
systemctl status <service>
```

---

## 5. PID Values Need Context

PID `1` appearing before and after reboot does not establish process continuity.

The system reused PID `1` for the new systemd process created during the new boot.

Boot-specific evidence such as `boot_id` provides the missing context.

---

## 6. Runtime State Is Broader Than Processes

Runtime state can include:

* Running processes
* Memory contents
* Network connections
* Open resources
* Boot-specific state
* Current system state

Processes are therefore only one part of the running system.

---

## 7. Reboot Is a Useful Controlled Experiment

Rather than merely reading that files persist and processes do not, the lab tested the prediction directly:

```text
Hypothesis
    ↓
Reboot
    ↓
Reconnect
    ↓
Collect evidence
    ↓
Compare before vs after
    ↓
Update mental model
```

The incorrect prediction that `boot-test.txt` would disappear was disproved by direct system evidence.

---

# Useful Command Reference

| Engineering Question                                        | Command                                    |
| ----------------------------------------------------------- | ------------------------------------------ |
| How long has Linux been running since its most recent boot? | `uptime`                                   |
| What is running as PID 1?                                   | `ps -p 1`                                  |
| Does systemd consider the overall system operational?       | `systemctl is-system-running`              |
| Which service units are currently running?                  | `systemctl --type=service --state=running` |
| What uniquely identifies this boot?                         | `cat /proc/sys/kernel/random/boot_id`      |
| Reboot the Linux system                                     | `sudo reboot`                              |
| Inspect a systemd service and its processes/state           | `systemctl status <service>`               |
| Display the persistent test file                            | `cat ~/boot-test.txt`                      |

These commands are **reference material**, not syntax that must all be reproduced perfectly from memory.

The durable engineering skill is being able to ask:

> **What state am I trying to prove, and what independent system evidence can prove it?**

---

# Outcome

This lab demonstrated the ability to:

* Provision and access a disposable Linux EC2 instance.
* Establish network and SSH access.
* Use uptime as boot evidence.
* Identify systemd as PID 1.
* Distinguish the Linux kernel from userspace processes.
* Query the overall systemd operational state.
* Inspect running systemd service units.
* Interpret `UNIT`, `LOAD`, `ACTIVE`, and `SUB`.
* Distinguish `active/running` from `enabled`.
* Distinguish a service unit from its associated processes.
* Capture a unique Linux boot ID.
* Deliberately reboot a Linux server.
* Validate a new boot using independent evidence.
* Test persistent storage across reboot.
* Distinguish persistent state from runtime state.
* Demonstrate that processes are recreated after reboot.
* Explain why the same PID across different boots does not mean the same process survived.
* Use SSH service evidence to trace systemd starting a service and creating a new process after boot.
* Correct misconceptions using observed system behaviour rather than assumptions.

The central systems lesson was:

> **Persistent storage provides the files and definitions needed to build the system, but a boot creates a new running system from them. Processes and boot-specific runtime state are recreated; persistent data remains.**

---

## Project Status

**Module 01 — Systems — Lab 4: Complete**
