# Module 02 — Lab 2: Linux Service Management with systemd

## Business Problem

Bob’s Burger needed a reliable way to run its Python HTTP server as a managed Linux service rather than relying on an engineer to start the application manually.

The application needed to run under a dedicated non-human service account, serve HTTP requests on port `8080`, and start automatically whenever the Linux server rebooted.

Administrators also needed a reliable way to inspect the service, investigate startup failures, and restore functionality without applying unnecessary configuration changes.

## What I Built

- Created a Python HTTP server serving Bob’s Burger content from `/srv/bobs-burgers` on port `8080`.
- Configured the dedicated `bobs-app` service account to run the application without root privileges.
- Created a custom systemd unit file at `/etc/systemd/system/bobs-burgers.service`.
- Configured the service's execution identity, working directory, startup command, and automatic restart behaviour.
- Enabled the service to start automatically during the Linux boot process.
- Rebooted the EC2 instance and verified that systemd automatically started a new Python process.
- Introduced a controlled startup failure by configuring a nonexistent working directory.
- Investigated the failure using `systemctl status` and `journalctl`, identified the `200/CHDIR` error, repaired the configuration, and validated recovery.

## Service Architecture

The application was configured around systemd-managed process execution:

```text
Amazon Linux 2023 EC2 Instance
│
└── systemd (PID 1)
    │
    ├── bobs-burgers.service
    │   │
    │   ├── User=bobs-app
    │   ├── WorkingDirectory=/srv/bobs-burgers
    │   ├── ExecStart=/usr/bin/python3 -m http.server 8080
    │   └── Restart=on-failure
    │
    └── Python HTTP Server Process
        │
        ├── Runs as bobs-app
        ├── Serves /srv/bobs-burgers
        └── Listens on TCP port 8080
                │
                ▼
        HTTP GET localhost:8080
                │
                ▼
           Bob's Burgers
```

### systemd Service Management

I used systemd, the Linux system and service manager, to manage the Python HTTP server.

Rather than starting the Python process manually from an SSH session, systemd manages its lifecycle according to the service unit configuration.

The `systemctl` command-line interface communicates with systemd to perform operations such as starting, stopping, restarting, enabling, and inspecting services.

This separates application execution from an engineer's interactive terminal session.

### Custom Service Unit

I created the following unit file:

```ini
[Unit]
Description=Bob's Python HTTP Server

[Service]
User=bobs-app
WorkingDirectory=/srv/bobs-burgers
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

The unit contains three sections:

- **`[Unit]`** — provides metadata and can define dependencies and startup ordering.
- **`[Service]`** — defines how the application process executes, including its identity, working directory, startup command, and restart policy.
- **`[Install]`** — defines how the unit participates in enablement relationships, including automatic startup through a target.

### Service Account Design

The application was configured to run under the dedicated `bobs-app` identity:

```ini
User=bobs-app
```

The account was created as a non-human system account:

```bash
sudo useradd -r -s /sbin/nologin bobs-app
```

The application directory and its content were configured so the service account could access them.

Using a dedicated identity avoids unnecessarily executing the HTTP server as `root` and provides separation between application processes and human administrator accounts.

### Working Directory and Process Execution

The unit specifies:

```ini
WorkingDirectory=/srv/bobs-burgers
ExecStart=/usr/bin/python3 -m http.server 8080
```

`WorkingDirectory=` establishes the directory from which the Python process executes.

`ExecStart=` specifies the executable and arguments used to start the HTTP server.

When the service starts, systemd prepares the process environment, including its configured working directory and execution identity, before successfully executing Python.

The HTTP server then serves content from `/srv/bobs-burgers` on port `8080`.

## Automatic Startup and Boot Persistence

### Enabling the Service

After creating the unit file, I reloaded systemd's configuration and started the service:

```bash
sudo systemctl daemon-reload
sudo systemctl start bobs-burgers.service
```

`daemon-reload` makes systemd reread unit configurations. It does not independently restart an already-running application process.

I then configured automatic startup:

```bash
sudo systemctl enable bobs-burgers.service
```

This created the symbolic link:

```text
/etc/systemd/system/multi-user.target.wants/bobs-burgers.service
    →
/etc/systemd/system/bobs-burgers.service
```

The relationship means that `multi-user.target` pulls in the enabled service during startup.

Importantly, `WantedBy=multi-user.target` establishes an enablement relationship rather than guaranteeing that the target is fully reached before the service starts.

### Boot Persistence Validation

I verified enablement using:

```bash
systemctl is-enabled bobs-burgers.service
```

Result:

```text
enabled
```

Before rebooting, the service's main process had PID `5037`.

I rebooted the EC2 instance and reconnected to verify whether the application started automatically without manual intervention.

After reboot, `systemctl status` reported:

```text
Loaded: loaded (...; enabled; preset: disabled)
Active: active (running)
Main PID: 1429 (python3)
```

The new PID demonstrated that systemd had started a new Python process after the reboot rather than preserving the original process.

I then tested the application:

```bash
curl http://localhost:8080
```

Response:

```text
Bob's Burgers
```

This confirmed both automatic service startup and HTTP functionality after reboot.

## Troubleshooting & Recovery

### Symptom

I deliberately introduced a startup failure by changing the service's working directory to a nonexistent path:

```ini
WorkingDirectory=/srv/does-not-exist
```

After reloading the unit configuration and restarting the service, the application failed to start.

### Evidence

I inspected the service:

```bash
systemctl status bobs-burgers.service
```

The output showed:

```text
Active: failed (Result: exit-code)
Main PID: 15888 (code=exited, status=200/CHDIR)
```

The service was still enabled for automatic startup, but it was no longer running successfully.

This demonstrated that **service enablement and runtime health are separate states**.

I investigated the journal:

```bash
sudo journalctl -u bobs-burgers.service -n 20 --no-pager
```

The journal reported:

```text
Changing to the requested working directory failed:
No such file or directory

Failed at step CHDIR spawning /usr/bin/python3:
No such file or directory
```

It also showed repeated restart attempts followed by:

```text
Start request repeated too quickly.
```

### Root Cause

The configured working directory did not exist.

Systemd successfully read the unit configuration but failed while attempting to establish the requested working directory during process startup.

The error:

```text
status=200/CHDIR
```

indicated a failure to change directories before Python successfully executed.

This was a runtime process-setup failure rather than a unit-file syntax error or a Python application crash.

Because the unit specified:

```ini
Restart=on-failure
```

systemd repeatedly attempted to restart the service.

However, restarting could not resolve the missing directory. After repeated failures, systemd reached its start-rate limit and stopped retrying.

### Recovery

I restored the intended working directory:

```ini
WorkingDirectory=/srv/bobs-burgers
```

I then executed:

```bash
sudo systemctl daemon-reload
sudo systemctl reset-failed bobs-burgers.service
sudo systemctl start bobs-burgers.service
```

These commands performed three separate operations:

1. **`daemon-reload`** — made systemd reread the corrected unit configuration.
2. **`reset-failed`** — cleared the failed state and restart-rate counter.
3. **`start`** — requested a new service startup using the corrected configuration.

I corrected the underlying configuration rather than attempting to hide the failure through repeated restarts.

### Validation

I checked the recovered service:

```bash
systemctl status bobs-burgers.service
```

The output showed:

```text
Loaded: loaded (...; enabled; preset: disabled)
Active: active (running)
Main PID: 23901 (python3)
```

I then verified HTTP functionality:

```bash
curl http://localhost:8080
```

Response:

```text
Bob's Burgers
```

This demonstrated that:

- the corrected unit configuration was successfully applied;
- systemd started a new Python process;
- the service returned to the `active (running)` state;
- automatic startup remained enabled;
- the HTTP server successfully served application content.

## Lessons Learned

- systemd provides a way to manage application processes independently of an engineer's interactive terminal session.
- A systemd service unit defines how an application process should execute, including its identity, working directory, startup command, and restart behaviour.
- `systemctl` is the command-line interface used to communicate with the systemd service manager.
- `systemctl daemon-reload` updates systemd's understanding of unit configurations, while `systemctl restart` restarts the running service using the updated configuration.
- `systemctl start` starts a service immediately, while `systemctl enable` configures its automatic startup through the unit's enablement relationships.
- `WantedBy=` defines an enablement relationship, whereas `After=` controls startup ordering when the relevant units are being started.
- A service configured with `After=network.target` is not guaranteed to have working network connectivity when it starts.
- `Restart=on-failure` allows systemd to attempt recovery from process failures, but it cannot repair an underlying configuration or filesystem problem.
- `200/CHDIR` indicates that systemd failed to establish the configured working directory before successfully executing the application.
- `systemctl status` provides evidence about service state, while `journalctl` provides more detailed service logs for investigating failures.
- An `active (running)` service does not necessarily mean its application is functioning correctly. Application-level validation, such as an HTTP request using `curl`, is also necessary.
- Reliable troubleshooting requires identifying the symptom, collecting evidence, establishing the root cause, applying a targeted fix, and independently validating recovery.

## Project Status

**Complete**

Custom systemd service configuration, dedicated service-account execution, automatic startup after reboot, process management, controlled startup failure, journal-based diagnosis, configuration repair, and HTTP validation were successfully demonstrated.
