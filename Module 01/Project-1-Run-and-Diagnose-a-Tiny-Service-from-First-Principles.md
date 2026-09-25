# Module 01 — Project 1: Run and Diagnose a Tiny Service from First Principles

## Business Problem

Bob's Burger Corporation wants its cloud engineers to understand what is actually happening underneath a running service rather than treating an application as a black box.

The task was to run a small HTTP service, trace it from a stored program to a running process, prove its operating-system and network state using evidence, and diagnose controlled failures without making random configuration changes.

## Project Goal

Run a local Python HTTP server on TCP port `8080` and demonstrate the relationship between:

```text
Stored program → Process → RAM → CPU
                         ↓
                        CWD
                         ↓
                  Listening socket
                         ↓
                     TCP/8080
                         ↓
                HTTP request/response
```

The project also required three controlled failure investigations:

- Stopped process
- Missing filesystem resource
- Bad `$PATH` / command resolution

---

# Build and Runtime Investigation

## Start the Service

The service was started from the Downloads directory:

```bash
python3 -m http.server 8080
```

Python reported:

```text
Serving HTTP on :: port 8080 (http://[::]:8080/) ...
```

This was useful application-level evidence, but the service still needed to be verified independently from the operating system and from the client side.

---

## Identify the Running Process

```bash
ps aux | grep '[h]ttp.server'
```

The server was identified as:

```text
PID 51361
```

The pattern `[h]ttp.server` avoided matching the `grep` process itself.

### Key Concept

> A **program** is stored instructions/code. A **process** is a running instance of a program.

The existence of the Python program on storage therefore does not prove that a Python server process currently exists.

---

## Inspect CPU and Memory

```bash
ps -p 51361 -o pid,%cpu,%mem,command
```

Observed:

```text
PID    %CPU  %MEM  COMMAND
51361  0.0   0.0   ...Python -m http.server 8080
```

A running process does not have to continuously consume measurable CPU.

At this observation point, the server was largely waiting for work. When work needs to be performed, the CPU executes instructions associated with the process using code/data available through memory.

---

## Prove the Listening Socket

```bash
lsof -i :8080
```

Observed:

```text
Python  51361  ...  TCP *:http-alt (LISTEN)
```

This independently demonstrated that a Python process had an OS-managed TCP socket listening on port `8080`.

The important relationship was:

```text
Protocol + local address + port
              ↓
       listening socket
              ↓
           process
```

A port number alone is not the complete identity of a network listener.

### Listening-Socket Mental Model

A listening socket waits for and accepts incoming connections.

```text
Client
  ↓
TCP connection
  ↓
Destination TCP port 8080
  ↓
Listening socket
  ↓ accepts connection
Python process
  ↓
Handles HTTP request
```

This produced an important operational distinction:

> **A running process does not necessarily mean that the expected network service is listening.**

---

## Validate the Service End to End

```bash
curl http://localhost:8080
```

The request returned an HTTP directory listing.

This provided stronger validation than process or socket evidence alone:

```text
Process exists
     ↓
Listener exists
     ↓
Client connects
     ↓
HTTP request handled
     ↓
Expected response returned
```

Each observation answers a different engineering question.

---

# Stored Program vs Running Process

## Locate the Stored Python Program

```bash
which python3
```

Observed:

```text
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3
```

Inspection showed that `python3` was a symbolic link:

```bash
ls -l /Library/Frameworks/Python.framework/Versions/3.13/bin/python3
```

```text
python3 -> python3.13
```

The target existed as a regular executable file:

```text
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

This provided filesystem evidence of the stored program independently of whether a server process was currently running.

---

## Inspect the Running Process's Executable Evidence

```bash
lsof -p 69922 | grep ' txt '
```

The output included:

```text
/Library/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python
```

Other mapped libraries/modules also appeared.

### Lesson Learned

`txt` in `lsof` represents mapped program text/code. Therefore, not every `txt` entry should be interpreted as "the executable."

The durable distinction is:

```text
Executable/program on storage
            ≠
Running process instance
```

---

# Process Current Working Directory

The restarted server later ran as PID `69922`.

Its CWD was inspected with:

```bash
lsof -a -p 69922 -d cwd
```

Observed:

```text
Python  69922  suleymanmohamud  cwd  DIR  ...  /Users/suleymanmohamud/Downloads
```

Therefore:

```text
Process CWD
/Users/suleymanmohamud/Downloads
```

For this Python `http.server` invocation, the CWD determined the directory being served.

The relationship was:

```text
Process CWD
     ↓
Served directory
     ↓
Requested URL path
     ↓
Filesystem resource
     ↓
HTTP response
```

For example:

```text
CWD = /Users/suleymanmohamud/Downloads

GET /orders.txt
        ↓
Downloads/orders.txt
        ↓
HTTP response
```

For `GET /`, Python's simple HTTP server serves `index.html` when appropriate if present; otherwise it can generate a directory listing.

---

# Controlled Failure 1 — Stopped Process

## Symptom

The working server was deliberately stopped using:

```text
Ctrl+C
```

Python reported:

```text
Keyboard interrupt received, exiting.
```

Rather than assuming the entire service state from that message, the resulting state was independently inspected.

## Evidence

```bash
ps -p 51361
```

Returned no process row.

Then:

```bash
lsof -i :8080
```

returned no output.

Finally:

```bash
curl http://localhost:8080
```

returned:

```text
curl: (7) Failed to connect to localhost port 8080 ...
```

## Root Cause

The server process had been terminated.

Its process-owned runtime resources were cleaned up, including the listener that had allowed clients to connect to the service.

## Important Observation

The stored Python executable remained on the filesystem.

```text
Process stopped
      ↓
Process instance gone
      ↓
Listener gone

BUT

Python executable on storage
      ↓
Still exists
```

Stopping a process and deleting a stored program are different lifecycle events.

## Fix

The server was started again:

```bash
python3 -m http.server 8080
```

The restarted server received a new PID.

## Validation

The process, listener and HTTP response were checked again.

This demonstrated:

> **Recovery is not proven merely because a restart command was issued. The resulting system behaviour must be validated.**

---

# Controlled Failure 2 — Missing Filesystem Resource

## Symptom

With the server running:

```bash
curl -i http://localhost:8080/orders.txt
```

returned:

```text
HTTP/1.0 404 File not found
```

This was fundamentally different from a connection failure.

The HTTP response demonstrated that the client had reached the server and that the server had processed the request.

## Evidence

The requested resource was searched for beneath the served directory:

```bash
find /Users/suleymanmohamud/Downloads -name 'orders.txt'
```

No result was returned.

## Root Cause

`orders.txt` did not exist at the filesystem location corresponding to the requested resource.

This was a **served-filesystem-resource problem**, not a `$PATH` problem.

## Fix

```bash
echo "Bob's Burger orders" > /Users/suleymanmohamud/Downloads/orders.txt
```

## Validation

Filesystem state was verified:

```bash
find /Users/suleymanmohamud/Downloads -name 'orders.txt'
ls -l /Users/suleymanmohamud/Downloads/orders.txt
cat /Users/suleymanmohamud/Downloads/orders.txt
```

The HTTP path was then tested again:

```bash
curl -i http://localhost:8080/orders.txt
```

Observed:

```text
HTTP/1.0 200 OK
...
Bob's Burger orders
```

The complete investigation was:

```text
HTTP 404
   ↓
Server was reachable
   ↓
Check requested filesystem resource
   ↓
orders.txt absent
   ↓
Create resource
   ↓
HTTP 200
```

---

# Controlled Failure 3 — Bad `$PATH`

## Scenario

A small executable called `bob-service` was created:

```bash
mkdir -p ~/bobs-tools

printf '#!/bin/sh\necho "Bob service tool started"\n' > ~/bobs-tools/bob-service

chmod +x ~/bobs-tools/bob-service
```

The executable existed:

```text
/Users/suleymanmohamud/bobs-tools/bob-service
```

However, running:

```bash
bob-service
```

returned:

```text
zsh: command not found: bob-service
```

## Evidence

The executable was located:

```bash
find ~ -name 'bob-service' 2>/dev/null
```

Observed:

```text
/Users/suleymanmohamud/bobs-tools/bob-service
```

The `$PATH` was then inspected:

```bash
echo $PATH
```

The `bobs-tools` directory was absent.

## Root Cause

The executable existed, but the shell was not configured to search its directory when resolving the command name `bob-service`.

This established the distinction:

```text
Filesystem
    ↓
"Does the executable exist?"

$PATH
    ↓
"Can the shell resolve this command name?"
```

## Fix

The directory was added without discarding the existing `$PATH`:

```bash
export PATH="$HOME/bobs-tools:$PATH"
```

## Validation

```bash
which bob-service
```

returned:

```text
/Users/suleymanmohamud/bobs-tools/bob-service
```

Then:

```bash
bob-service
```

returned:

```text
Bob service tool started
```

---

# Failure-Layer Mental Model

One of the most important lessons from the project was learning not to collapse different symptoms into the same problem.

```text
"command not found"
        ↓
Command resolution / $PATH


"Failed to connect to port 8080"
        ↓
Network listener / connectivity


"HTTP 404 File not found"
        ↓
Server was reached
        ↓
Requested resource / served filesystem
```

The symptom helps determine **which layer should be investigated first**.

---

# Troubleshooting Method

The project used an evidence-first troubleshooting loop:

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

A key example occurred when considering:

```text
Process exists
+
curl cannot connect to TCP/8080
```

The next step is **not automatically to restart the application**.

The next evidence should establish whether the expected listening socket actually exists:

```bash
lsof -i :8080
```

If nothing is listening, that establishes:

> The process exists, but the expected TCP listener does not.

It does **not yet establish why** the listener is absent.

Restarting immediately could change the failed state and destroy useful diagnostic evidence before the root cause is understood.

---

# System Lifecycle

The complete mental model developed during the project was:

```text
POWER ON
   ↓
Firmware initializes hardware
and locates/starts bootloader
   ↓
Bootloader locates kernel on storage
   ↓
Kernel loaded into RAM
   ↓
Kernel takes control
   ↓
Userspace initialized
   ↓
systemd starts as PID 1
   ↓
Operating system creates process
   ↓
Required program code/data mapped into memory
   ↓
CPU executes instructions
   ↓
Python server process running
   ↓
OS-managed listening socket
bound to TCP/8080
   ↓
Client establishes TCP connection
   ↓
HTTP request
   ↓
Python handles request
   ↓
CWD + requested URL path
determine filesystem resource
   ↓
HTTP response
```

This connects storage, boot, operating system, processes, RAM, CPU, filesystem context and networking into one observable system.

---

# Engineering Lessons Learned

## 1. Stored Program ≠ Running Process

A program can remain on storage while no corresponding process exists.

Starting the program creates a new process instance. Stopping that process does not inherently delete the stored program.

## 2. Process Running ≠ Service Working

`ps` can prove that a process exists.

It cannot by itself prove that the expected network listener exists or that an end-to-end request succeeds.

## 3. A Listening Socket Is Specific Evidence

A listening socket provides evidence that a process is waiting for incoming connections on a particular network endpoint.

```text
Protocol + local address + port
              ↓
       listening socket
              ↓
           process
```

## 4. CWD Has Operational Consequences

A process's working directory is not merely shell trivia.

For this Python HTTP server, it determined the root of the filesystem content being served.

## 5. Similar-Looking Failures Can Belong to Different Layers

`command not found`, connection failure and HTTP `404` require different first investigations.

Correctly identifying the layer prevents random troubleshooting.

## 6. Current-State Evidence Does Not Explain History

A command such as `ps` can show whether a process exists **now**.

It does not necessarily explain why a process previously stopped or failed to start. Historical evidence may instead come from logs, a service manager or other application/system records.

## 7. Diagnose Before Changing the System

A restart may restore service without explaining the failure.

The stronger engineering approach is:

> **Observe → hypothesize → test → identify root cause → fix → validate.**

---

# Useful Command Reference

| Engineering Question | Command |
|---|---|
| Find the HTTP-server process | `ps aux \| grep '[h]ttp.server'` |
| Inspect CPU/memory for a PID | `ps -p <PID> -o pid,%cpu,%mem,command` |
| Inspect resources associated with port 8080 | `lsof -i :8080` |
| Inspect a process's CWD | `lsof -a -p <PID> -d cwd` |
| Inspect mapped program text/code | `lsof -p <PID> \| grep ' txt '` |
| Check whether a PID still exists | `ps -p <PID>` |
| Test the HTTP service | `curl http://localhost:8080` |
| Inspect `$PATH` | `echo $PATH` |
| Check shell command resolution | `which <command>` |
| Search for a filesystem resource | `find <directory> -name '<name>'` |

These are reference commands rather than syntax that must all be reproduced perfectly from memory.

The durable skill is:

> **Know what evidence you need, then choose an observation that can provide it.**

---

# Outcome

This project demonstrated the ability to:

- Trace a system from boot through userspace and process execution.
- Distinguish a stored program from a running process.
- Identify a process and inspect its runtime state.
- Reason about CPU and memory usage.
- Identify a process's current working directory.
- Verify a TCP listening socket independently.
- Validate an HTTP service end to end.
- Explain how CWD affects served filesystem content.
- Stop and recover a service while validating the resulting state.
- Diagnose a missing served resource.
- Diagnose a `$PATH` / command-resolution failure.
- Distinguish process, network and application/filesystem failure layers.
- Troubleshoot using evidence before changing system state.

The central engineering lesson was:

> **Do not equate process existence with service health. Identify the failing layer, gather evidence, test your hypothesis, fix the root cause, and validate recovery.**

---

## Project Status

**Module 01 — Systems — Project 1: Complete**
