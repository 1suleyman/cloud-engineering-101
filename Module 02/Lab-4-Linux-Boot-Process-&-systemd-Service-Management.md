MODULE 01 — LAB 4

# Linux Boot Process & systemd Service Management

## Business Problem

Bob’s Burger needed a Linux server capable of automatically starting an internal application after reboot, while allowing engineers to investigate startup failures, inspect service dependencies, and validate that the application was actually responding.

The solution needed to distinguish between a service being configured to start automatically, a process currently running, and an application successfully serving requests.

## What I Built

- Investigated the Linux boot sequence from firmware and bootloader through to the Linux kernel, systemd, and SSH.
- Inspected systemd as PID 1 and reviewed running services and boot-related logs.
- Examined the `sshd.service` unit file to understand startup configuration, dependencies, ordering, and restart behaviour.
- Created a custom `bobs-test.service` systemd unit.
- Introduced a controlled startup failure using a nonexistent executable.
- Diagnosed the failure using `systemctl status` and `journalctl`.
- Repaired the service and validated successful execution.
- Enabled the service through `multi-user.target` to configure automatic startup.
- Replaced the temporary process with a Python HTTP server listening on `127.0.0.1:8080`.
- Rebooted the EC2 instance and verified that systemd automatically restarted the application.
- Confirmed application responsiveness using an HTTP request.

## Linux Boot Architecture

The boot process was investigated using an AWS EC2 Linux instance.

```
EC2 Instance Starts
        │
        ▼
Firmware
        │
        ▼
Bootloader
        │
        ▼
Linux Kernel
        │
        ▼
systemd (PID 1)
        │
        ├── sshd.service
        │
        ├── Other System Services
        │
        └── bobs-test.service
                  │
                  ▼
             Python HTTP Server
                  │
                  ▼
           127.0.0.1:8080
```

### Boot Sequence

The boot process follows several stages:

1. Firmware initializes the virtual hardware environment and begins the boot process.
2. Bootloader locates and loads the Linux kernel into memory.
3. Linux kernel initializes core operating-system components and eventually starts the init process.
4. systemd (PID 1) manages the startup of system services and other units.
5. SSH service starts as part of the configured system startup, allowing remote administration.

I verified that systemd was running as PID 1 using:

```
ps -p 1
```

The output identified:

```
systemd
```

I also inspected system uptime and running processes using:

```
uptime
ps aux
```

This helped distinguish the operating system's boot process from the processes running after startup.

## Boot Health Investigation

Before creating a custom service, I examined the system's existing service health and boot logs.

### Failed Services

```
systemctl --failed
```

The output showed:

```
0 loaded units listed.
```

This indicated that systemd had no units currently recorded in the failed state.

It did not necessarily mean that no transient failures had occurred earlier.

### Boot Error Logs

```
journalctl -b -p err --no-pager
```

The journal included a kernel security warning concerning RETBleed and Spectre v2 mitigations.

I distinguished this kernel warning from an application startup failure rather than assuming that every error-level log entry indicated a failed service.

## Understanding systemd Unit Files

I inspected the existing SSH service configuration:

```
systemctl cat sshd.service
```

The unit contained directives including:

```
[Unit]
After=network.target sshd-keygen.target
Wants=sshd-keygen.target

[Service]
Type=notify
ExecStart=/usr/sbin/sshd -D $OPTIONS
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
```

### Dependency and Ordering Design

Two important directives are:

```
Wants=sshd-keygen.target
After=network.target sshd-keygen.target
```

They perform different functions.

```
Wants=
   │
   ▼
Requests activation of another unit
(weak dependency)


After=
   │
   ▼
Controls startup ordering
when both units have startup jobs
```

`Wants=` attempts to activate the referenced unit but does not normally require that unit to succeed.

`After=` specifies ordering. It does not independently activate the referenced unit.

Neither directive guarantees that an application is healthy or ready to serve requests.

### Service Execution

The `ExecStart=` directive specifies the command systemd executes when starting a service.

For example:

```
ExecStart=/usr/sbin/sshd -D $OPTIONS
```

The `Restart=on-failure` directive configures systemd to attempt restarting the service after qualifying failures.

The unit's `WantedBy=multi-user.target` directive provides installation information used when enabling the service.

## Custom Service Configuration

I created a custom unit file:

```
/etc/systemd/system/bobs-test.service
```

The initial configuration was:

```
[Unit]
Description=Bob's Burger Controlled Failure Test

[Service]
Type=simple
ExecStart=/usr/local/bin/bobs-app-missing

[Install]
WantedBy=multi-user.target
```

This intentionally referenced an executable that did not exist.

After creating the unit, I instructed systemd to reload its unit configuration:

```
sudo systemctl daemon-reload
```

This is required after editing a unit file so systemd can read the updated configuration.

## Troubleshooting & Recovery

### Symptom

I attempted to start the custom service:

```
sudo systemctl start bobs-test.service
```

The service subsequently entered a failed state.

### Evidence

I inspected the service logs and status.

```
journalctl -u bobs-test.service --no-pager
```

The journal reported:

```
Failed to locate executable
/usr/local/bin/bobs-app-missing:
No such file or directory

Failed at step EXEC spawning
/usr/local/bin/bobs-app-missing

Main process exited,
code=exited, status=203/EXEC

Failed with result 'exit-code'
```

The service status also showed:

```
Active: failed (Result: exit-code)
```

### Root Cause

The `ExecStart=` directive referenced a nonexistent executable:

```
ExecStart=/usr/local/bin/bobs-app-missing
```

Systemd was unable to execute the configured program.

The `203/EXEC` status identified an execution-stage failure.

Possible causes of this status include missing executables, incorrect execution permissions, invalid interpreters, and executable-format problems.

In this investigation, the journal identified the specific cause: the executable did not exist.

### Recovery

I replaced the invalid executable with a valid command:

```
ExecStart=/usr/bin/sleep 300
```

I then reloaded the configuration, cleared the failed state, and started the service:

```
sudo systemctl daemon-reload
sudo systemctl reset-failed bobs-test.service
sudo systemctl start bobs-test.service
```

### Validation

I checked the service:

```
systemctl status bobs-test.service
```

The result showed:

```
Active: active (running)
```

The process was executing:

```
/usr/bin/sleep 300
```

This demonstrated that the execution failure had been corrected.

`systemctl reset-failed` cleared the recorded failed state and relevant failure counters, but the underlying repair was the correction to `ExecStart=`.

## Automatic Startup Configuration

After validating the service, I enabled it:

```
sudo systemctl enable bobs-test.service
```

Systemd created the following symlink:

```
/etc/systemd/system/
│
├── bobs-test.service
│
└── multi-user.target.wants/
    │
    └── bobs-test.service
        └── symlink to ../bobs-test.service
```

The unit contained:

```
[Install]
WantedBy=multi-user.target
```

This identifies the target that should acquire a `Wants` relationship when the service is enabled.

The `enable` command creates the corresponding symlink.

### Enabled vs Active

These are separate states:

```
Enabled
   │
   ▼
Configured for automatic startup


Active (running)
   │
   ▼
Service process currently running
```

A service can be enabled but inactive, or disabled but currently running.

Enabling the service does not necessarily start it immediately.

For example:

```
sudo systemctl enable --now bobs-test.service
```

would both enable and start the service.

## HTTP Application Configuration

The temporary `sleep` process was useful for demonstrating service execution, but it did not provide an application-level response to validate.

I replaced it with Python's built-in HTTP server.

The final unit configuration was:

```
[Unit]
Description=Bob's Burger Controlled Failure Test

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 127.0.0.1

[Install]
WantedBy=multi-user.target
```

The instance had Python 3 installed at:

```
/usr/bin/python3
```

The installed version was:

```
Python 3.9.25
```

The plain `python` command was unavailable, so I used the verified absolute path to Python 3.

### Network Binding

The server was configured with:

```
--bind 127.0.0.1
```

This restricted the HTTP listener to the loopback interface.

I inspected the instance's network interfaces using:

```
ip -br addr
```

The output included:

```
lo     UNKNOWN  127.0.0.1/8 ::1/128

ens5   UP       172.31.39.83/20
```

The instance had two interfaces:

- `lo` — loopback interface used for local communication.
- `ens5` — virtual network interface carrying the EC2 private IPv4 address.

### Binding Design

```
EC2 Instance
│
├── lo
│   └── 127.0.0.1
│       └── Python HTTP Server :8080
│
└── ens5
    └── 172.31.39.83
        └── VPC Network Connectivity
```

Binding to `127.0.0.1` meant the application accepted connections addressed to the local loopback address.

Binding to `0.0.0.0` would instead make the server listen on all local IPv4 interfaces, including the private network interface.

This does not bypass AWS security groups. Network binding and security-group rules serve different purposes.

I chose loopback binding because remote access was unnecessary for this lab.

Python's built-in HTTP server was used only for local testing, not as a production web server.

## Application Validation

After updating the unit, I reloaded systemd and started the service:

```
sudo systemctl daemon-reload
sudo systemctl start bobs-test.service
```

I then checked the current service state:

```
systemctl status bobs-test.service --no-pager
```

The result showed:

```
Loaded: loaded (...; enabled; preset: disabled)
Active: active (running)
Main PID: 3438 (python3)
```

The running command was:

```
/usr/bin/python3 -m http.server 8080 --bind 127.0.0.1
```

I then validated the HTTP endpoint:

```
curl -I http://127.0.0.1:8080
```

The response was:

```
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.9.25
Content-type: text/html; charset=utf-8
```

This confirmed that the application was responding to HTTP requests, not merely that a process existed.

## Reboot & Automatic Recovery Validation

### Objective

Verify that the HTTP server would start automatically after a normal EC2 operating-system reboot without manual intervention.

### Test

I rebooted the instance:

```
sudo reboot
```

After the SSH session disconnected, I reconnected to the EC2 instance.

I deliberately did not manually start `bobs-test.service`.

### Service Evidence

I checked the service:

```
systemctl status bobs-test.service --no-pager
```

The output showed:

```
Loaded: loaded (...; enabled; preset: disabled)

Active: active (running)
since Fri 2026-10-23 19:30:46 UTC

Main PID: 1781 (python3)
```

The service was automatically running after the reboot.

The Python process had a different PID from before the reboot:

```
Before reboot: PID 3438
After reboot:  PID 1781
```

This demonstrated that the original process had ended and systemd had started a new process.

The original Python process had not survived the reboot.

### Application Evidence

I independently checked the HTTP endpoint:

```
curl -I http://127.0.0.1:8080
```

The response was:

```
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.9.25
```

The application was responding after the reboot.

### Validation Result

The test demonstrated that:

- `bobs-test.service` remained enabled;
- systemd automatically started the service after reboot;
- a new Python process was created;
- the HTTP server was running on the expected loopback address and port;
- the application successfully responded to an HTTP request;
- no manual service start was required after reconnecting.

This validated both automatic service startup and basic application availability.

## Lessons Learned

- Linux startup involves several stages: firmware, bootloader, kernel initialization, and the init system.
- Systemd runs as PID 1 on this instance and manages system services and other units.
- A systemd `.service` unit describes how a service is managed, while a `.target` unit groups other units around an operational milestone.
- `Wants=` requests activation of another unit, while `After=` controls startup ordering. Neither guarantees application readiness.
- `WantedBy=` specifies installation relationships used when enabling a unit, while `systemctl enable` creates the corresponding symlink.
- Enabled and active are independent states: a service can be configured for automatic startup without currently running.
- `ExecStart=` specifies the command systemd executes when starting a service.
- `203/EXEC` indicates that systemd failed to execute the configured program; journal evidence is needed to identify the specific cause.
- `systemctl daemon-reload` makes systemd reread updated unit configurations.
- `systemctl reset-failed` clears recorded failure state and counters but does not fix the underlying problem.
- Service troubleshooting should begin with evidence from `systemctl status`, `journalctl`, and the unit configuration rather than repeated reboots.
- Binding to `127.0.0.1` restricts a server to loopback connections, while `0.0.0.0` listens on all local IPv4 addresses.
- A service reporting `active (running)` does not necessarily mean its application is functioning correctly.
- Application-level checks, such as HTTP requests, provide additional evidence beyond process state.
- An enabled service's automatic startup should be validated through a real reboot rather than assumed from its configuration.
- After reboot, systemd starts a new process; the original process does not persist across operating-system restarts.

## Project Status

**Complete** — Linux boot investigation, systemd unit inspection, controlled execution failure, diagnosis, recovery, automatic startup configuration, loopback HTTP service, reboot validation, and application responsiveness were demonstrated successfully.
