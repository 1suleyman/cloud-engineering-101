# Module 01 — Lab 4.3: Linux Application Troubleshooting & Recovery

## Business Problem

Bob's Burger Corporation needed engineers who could diagnose application startup failures and service outages on an AWS EC2 Linux instance without making random configuration changes or unnecessarily restarting infrastructure.

Three controlled failures were investigated:

- A missing application configuration file.
- An unset environment variable preventing application startup.
- A stopped HTTP server process causing service unavailability.

The objective was to identify each root cause using system evidence, apply a targeted fix, and validate recovery.

## What I Built

- Created three isolated lab workspaces under `/home/ec2-user` on an AWS EC2 instance.
- Built a Python application that required an external configuration file to start.
- Built a second Python application that validated its environment configuration before starting.
- Launched a Python HTTP server listening on TCP port `8080`.
- Reproduced three controlled failures and investigated their symptoms.
- Used filesystem checks, environment inspection, process inspection, and HTTP requests to collect evidence.
- Restored each application without rebooting EC2 or making unnecessary system-wide changes.

## Troubleshooting Approach

I followed an evidence-first troubleshooting process:

```text
Application failure
        |
        v
Observe the symptom
        |
        v
Collect system evidence
        |
        v
Form a hypothesis
        |
        v
Test the hypothesis
        |
        v
Identify the root cause
        |
        v
Apply a targeted fix
        |
        v
Validate recovery
```

The objective was to understand why the application failed before changing its configuration or restarting services.

---

## Incident 1 — Missing Application Configuration File

### Symptom

A Python application failed to start inside:

```text
/home/ec2-user/lab6-incident1
```

The application contained:

```python
from pathlib import Path

config = Path("app.conf")
settings = config.read_text()

print("Application started successfully!")
print(settings)
```

Running:

```bash
python3 app.py
```

produced:

```text
FileNotFoundError: [Errno 2]
No such file or directory: 'app.conf'
```

### Evidence

I investigated whether the required configuration file existed.

Initially, I used:

```bash
which app.conf
```

This was not the appropriate tool because `which` searches directories in `PATH` for executable commands, while `app.conf` was a configuration file.

I then searched for the file:

```bash
sudo find / -type f -name app.conf
```

No matching file was returned.

A targeted check also confirmed that the file was absent from the working directory:

```bash
ls -l app.conf
```

Output:

```text
ls: cannot access 'app.conf': No such file or directory
```

### Root Cause

The application attempted to read a configuration file that did not exist at its expected location.

The expression:

```python
config = Path("app.conf")
```

creates a Python path object. It does not create a file on disk.

The next operation:

```python
settings = config.read_text()
```

attempts to open and read that file.

Because `app.conf` is a relative path, Python resolves it against the process's current working directory.

```text
Process working directory
/home/ec2-user/lab6-incident1
             +
Relative path
app.conf
             |
             v
Resolved location
/home/ec2-user/lab6-incident1/app.conf
```

The file was missing, causing `read_text()` to raise `FileNotFoundError`.

### Recovery

I created the missing configuration file:

```bash
echo "APP_NAME=BobsBurger" > app.conf
```

During recovery, I initially executed the command from `/home/ec2-user` after reconnecting to EC2.

This created the file in the wrong location.

Attempting to run the application there produced:

```text
python3: can't open file '/home/ec2-user/app.py':
[Errno 2] No such file or directory
```

I corrected the working directory, removed the misplaced configuration file, and created it inside the application's lab workspace.

### Validation

Running:

```bash
python3 app.py
```

produced:

```text
Application started successfully!
APP_NAME=BobsBurger
```

The application successfully read the restored configuration file.

### Engineering Consideration

Relative paths depend on the process's current working directory, which is not necessarily the directory containing the Python script.

An absolute path identifies a specific filesystem location:

```python
Path("/home/ec2-user/lab6-incident1/app.conf")
```

Alternatively, an application can resolve a configuration file relative to the script itself:

```python
Path(__file__).resolve().parent / "app.conf"
```

The appropriate approach depends on how the application is deployed and where its configuration is expected to reside.

---

## Incident 2 — Missing Environment Variable

### Symptom

A second Python application failed during startup.

The application contained:

```python
import os

environment = os.environ.get("APP_ENV")

if environment not in ("development", "production"):
    raise RuntimeError("Application startup failed: invalid environment configuration")

print(f"Application started in {environment} mode")
```

Running:

```bash
python3 app.py
```

produced:

```text
RuntimeError: Application startup failed:
invalid environment configuration
```

### Evidence

I inspected the environment variable expected by the application:

```bash
printenv APP_ENV
```

The command returned no output.

This indicated that no value was being displayed for `APP_ENV` in the shell's exported environment.

### Root Cause

The application expected `APP_ENV` to contain either:

```text
development
```

or:

```text
production
```

However, the required environment variable was not configured in the shell environment used to launch the application.

The Python expression:

```python
os.environ.get("APP_ENV")
```

reads an environment variable from the Python process's environment.

It does not search the filesystem for a configuration file.

When the variable is absent, `.get()` returns `None` by default.

Because `None` was not an accepted value, the application raised `RuntimeError` and terminated.

### Recovery

I configured the environment variable in the current shell:

```bash
export APP_ENV=development
```

The `export` command makes the variable available to subsequently launched child processes.

I then verified the configuration:

```bash
printenv APP_ENV
```

Output:

```text
development
```

### Validation

I restarted the Python application:

```bash
python3 app.py
```

Output:

```text
Application started in development mode
```

The application successfully inherited the environment variable and passed its startup validation.

### Environment Variable Inheritance

The relationship between the shell and application process is:

```text
EC2 Linux Instance
        |
        v
Current Shell
        |
        | export APP_ENV=development
        |
        v
Python Child Process
        |
        | inherits exported environment
        |
        v
os.environ.get("APP_ENV")
        |
        v
"development"
        |
        v
Application starts successfully
```

### Temporary vs Persistent Configuration

The `export` command configured the variable for the current shell and its subsequently launched child processes.

It did not permanently configure the EC2 instance.

A new SSH session normally starts a new shell environment and would not automatically inherit the previous session's variable.

For interactive Bash sessions, persistent user-level configuration can be placed in a startup file such as:

```text
~/.bashrc
```

System services, including applications managed by `systemd`, may require their own environment configuration.

For this lab, a temporary shell-level change was sufficient and avoided unnecessary system-wide modifications.

---

## Incident 3 — Stopped HTTP Server Process

### Symptom

A Python HTTP server running on the EC2 instance became unavailable.

The service had initially been started using:

```bash
python3 -m http.server 8080
```

Output:

```text
Serving HTTP on 0.0.0.0 port 8080
```

The server ran in the foreground and listened for HTTP requests.

### Healthy Baseline

Before introducing the failure, I checked whether the server process existed:

```bash
ps aux | grep '[h]ttp.server'
```

The output identified the Python HTTP server process:

```text
ec2-user  2156  ...  python3 -m http.server 8080
```

I then tested the service from a second SSH session:

```bash
curl -i http://127.0.0.1:8080/
```

The server returned:

```text
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.9.25
Content-type: text/html; charset=utf-8
```

This confirmed that the process was running and the HTTP endpoint responded successfully.

### Controlled Failure

I pressed `Ctrl + C` in the terminal running the HTTP server.

The server reported:

```text
Keyboard interrupt received, exiting.
```

The foreground process terminated, and the shell prompt returned.

### Evidence

I repeated the HTTP request:

```bash
curl -i --max-time 5 http://127.0.0.1:8080/
```

Output:

```text
curl: (7) Failed to connect to 127.0.0.1:8080
Could not connect to server
```

I then inspected the process list:

```bash
ps aux | grep '[h]ttp.server'
```

No matching HTTP server process was returned.

Together, these observations supported the diagnosis that the application process had stopped and the service was no longer accepting connections.

### Root Cause

The Python HTTP server process had terminated.

While running, the application owned a listening socket bound to TCP port `8080`.

When the process exited, the operating system closed its listening socket.

```text
Healthy State

Python HTTP Server Process
          |
          v
Listening Socket
TCP port 8080
          |
          v
Client HTTP Request
          |
          v
HTTP 200 OK


Failure State

Python Process Terminates
          |
          v
Listening Socket Closes
          |
          v
No HTTP Server Listening
on TCP port 8080
          |
          v
Client Connection Fails
```

The EC2 instance itself remained running.

The failure affected the application process, not the availability of the entire virtual machine.

### Recovery

I restarted only the affected application:

```bash
python3 -m http.server 8080
```

Output:

```text
Serving HTTP on 0.0.0.0 port 8080
```

Restarting the entire EC2 instance was unnecessary because the evidence identified a stopped application process.

### Validation

From the second SSH session, I ran:

```bash
curl -i --max-time 5 http://127.0.0.1:8080/
```

The server returned:

```text
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.9.25
Content-type: text/html; charset=utf-8
```

This confirmed that the application was responding again through the tested local endpoint.

### Engineering Considerations

A running EC2 instance does not guarantee that applications hosted on it are running.

Similarly, a process appearing in the process list does not necessarily prove that its service is functioning correctly.

Different checks answer different questions:

| Check | What It Establishes |
|---|---|
| `ps` | Whether a matching process is visible |
| `ss` | Whether a socket is listening on a particular port |
| `curl` | Whether an HTTP endpoint responds from the tested client location |

The `ss` command is included as a useful future diagnostic technique; it was not executed during this incident.

A successful localhost request confirms local application responsiveness, but does not independently verify external connectivity through an EC2 Security Group, network ACL, or load balancer.

---

## Lessons Learned

- Application troubleshooting should begin with evidence rather than random configuration changes or infrastructure restarts.

- A Python `Path` object represents a filesystem path; it does not automatically create the referenced file.

- Relative paths resolve against a process's current working directory, which may differ from the script's location.

- Missing files should be investigated using filesystem evidence. The `PATH` environment variable is used for executable command lookup, not general configuration-file discovery.

- Environment variables provide configuration to processes without requiring the application to read a separate file.

- Exported shell variables are inherited by subsequently launched child processes, but are not automatically retained across independent SSH sessions.

- Application startup validation can fail when a required environment variable is absent or contains an unsupported value.

- A running EC2 instance does not mean every application process on that instance is healthy.

- A listening socket enables an application to receive network connections on a particular address and port. When its owning process terminates, the operating system closes that socket.

- Process inspection and HTTP requests provide different forms of evidence. Combining them produces a more reliable diagnosis than relying on either alone.

- Recovery should target the faulty component. Restarting a stopped application is preferable to rebooting an entire EC2 instance when the evidence supports that action.

- Recovery must be validated by repeating the relevant test and comparing the result against a known-working baseline.

## Project Status

**Three controlled incidents recovered and validated** — missing configuration file, missing environment variable, and stopped HTTP server process.

All three investigations demonstrated evidence-based troubleshooting and targeted recovery on an AWS EC2 Linux instance.
