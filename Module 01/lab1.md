# Module 01 — Lab 1: Investigating a Running Local Web Service

## Business Problem

Bob's Burger Corporation wants its junior cloud engineers to prove that a service is actually running rather than relying only on what the application reports.

The task was to launch a small local web service and use operating-system evidence to identify and verify its process, PID, CPU usage, memory usage, executable path, listening port, and current working directory. The service was then deliberately stopped so the failure and recovery could be verified from evidence.

## Project Goal

Launch a local Python HTTP server on port `8080` and build a live-system map showing how a stored program becomes a running process that consumes system resources and owns a listening network socket.

---

## Investigation

### Start the Service

```bash
python3 -m http.server 8080
```

Python reported:

```text
Serving HTTP on :: port 8080 ...
```

This was useful **application-level evidence**, but it was not sufficient independent proof of the operating-system state.

### Command Recognition

| Part | Meaning |
|---|---|
| `python3` | Python 3 interpreter |
| `-m` | Locate and run a Python module as a program |
| `http.server` | Python's built-in HTTP server module |
| `8080` | Port the server is configured to listen on |

---

### Find the Running Process

```bash
ps aux | grep http.server
```

The original server process was identified as:

```text
PID 48992
```

**Key concept:**

> A **program** is stored instructions/files. A **process** is a running instance of a program.

`grep` itself can also appear in this search because it is a separate process whose command line contains the search term.

---

### Inspect CPU and Memory Usage

Once the PID was known, I inspected that specific process:

```bash
ps -p 48992 -o pid,%cpu,%mem,command
```

Observed:

```text
PID    %CPU  %MEM  COMMAND
48992  0.0   0.1   /Library/Frameworks/Python.framework/Versions/3.13/...
```

At that observation point:

- **PID:** `48992`
- **CPU:** `0.0%`
- **Memory:** `0.1%`
- **Command:** Python HTTP server process

The `0.0%` CPU reading was consistent with a server that was running but idle at that moment.

---

### Prove the Listening Port

I independently checked what was using port `8080`:

```bash
lsof -i :8080
```

The operating system showed the Python process with a TCP socket on port `8080` in the `LISTEN` state.

Example:

```text
Python  48992  ...  TCP *:http-alt (LISTEN)
```

This was stronger evidence than simply trusting:

```text
Serving HTTP on :: port 8080
```

because `lsof` provided an **independent operating-system view** of the network state rather than relying only on the application's own claim.

### Command Recognition

- `lsof` — lists open files/resources held by processes.
- `-i` — selects network-related open files/sockets.
- `:8080` — scopes the query to port `8080`.

---

### Investigate the Executable Path

I inspected program code mapped into the process:

```bash
lsof -p 48992 | grep txt
```

The output included:

```text
/Library/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python
```

It also returned Python libraries and modules such as `_socket`, `_ssl`, and `libcrypto`.

### Lesson Learned

In `lsof`, `txt` refers to **program text/code mapped into a process**. It does not simply mean ordinary text files.

Multiple results appeared because the running Python process had executable code and multiple libraries/modules mapped into it.

> **Precision note:** The `txt` output gave useful executable-path evidence, but the first `txt` result should not be treated as a universal rule for identifying a process's main executable.

---

### Find the Current Working Directory

I inspected the process's current working directory:

```bash
lsof -a -p 48992 -d cwd
```

Observed:

```text
Python  48992  suleymanmohamud  cwd  DIR  ...  /Users/suleymanmohamud
```

The process therefore had:

```text
/Users/suleymanmohamud
```

as its **current working directory (CWD)**.

The CWD is the process's current filesystem context, including the reference point used for relative filesystem paths.

### Command Recognition

- `-p 48992` — select PID `48992`
- `-a` — combine selection conditions using AND
- `-d cwd` — select the current-working-directory category
- `DIR` — directory

---

# Controlled Break/Fix

## Introduce the Fault

I deliberately stopped the HTTP server using:

```text
Ctrl+C
```

Python reported:

```text
Keyboard interrupt received, exiting.
```

Rather than assuming the service had stopped correctly, I verified the resulting system state independently.

---

## Prove the Process Had Stopped

I queried the old PID:

```bash
ps -p 48992
```

The command returned only its headings:

```text
PID TTY TIME CMD
```

There was no process row.

This proved that **PID `48992` was no longer an active process**.

---

## Prove the Listener Had Disappeared

I then checked port `8080`:

```bash
lsof -i :8080
```

No entries were returned.

This proved that, at that observation point:

> **No process had a network socket associated with port `8080`.**

This distinction matters. `lsof -i :8080` was not asking specifically about PID `48992`. Another process could theoretically have been using the same port.

---

# Recovery and Validation

I restarted the Python HTTP server.

A new process search showed the server running as:

```text
PID 50940
```

I then checked port `8080` again:

```bash
lsof -i :8080
```

The output included:

```text
Python  50940  ...  TCP *:http-alt (LISTEN)
```

The complete observed transition was:

```text
Healthy service
      ↓
PID 48992 running
      ↓
Port 8080 listening
      ↓
Ctrl+C
      ↓
PID 48992 absent
      ↓
No socket associated with port 8080
      ↓
Service restarted
      ↓
New PID 50940
      ↓
Port 8080 listening again
```

The restarted service created a **new process instance**, which explains why it received a new PID.

---

# Live-System Mental Model

This lab connected the systems concepts into one observable model:

```text
Program stored on disk
        ↓
Python interpreter starts
        ↓
Running process / PID
        ↓
 ┌──────┼────────────┐
 ↓      ↓            ↓
CPU   Memory        CWD
                     ↓
               Network socket
                     ↓
                 Port 8080
                 LISTEN
```

Stopping the process removed the running process instance and its listener.

Restarting the service created a new process instance and restored the listener.

---

# Engineering Lessons Learned

## 1. Application Claims Are Not Independent Proof

An application reporting that it has started is useful evidence, but operating-system tools can independently verify whether the expected process and network state actually exist.

---

## 2. Different Tools Answer Different Questions

`ps` provided **process-level evidence**.

`lsof` provided evidence about **resources held by processes**, including network sockets and the current working directory.

Combining multiple observations provided stronger evidence than relying on one output.

---

## 3. Diagnose Before Changing Configuration

The break/fix followed an evidence-first troubleshooting pattern:

```text
Symptom
   ↓
Evidence
   ↓
Hypothesis
   ↓
Test
   ↓
Root Cause / Fault
   ↓
Fix
   ↓
Validation
```

I verified the failed state before recovery and then independently verified recovery rather than assuming the restart worked.

---

## 4. A Listener Is Held by a Running Process

The Python server process held the listening network socket.

When the process terminated, its listener disappeared.

Restarting the service created a new process and restored the listener.

---

## 5. PIDs Identify Process Instances

The original server used:

```text
PID 48992
```

The restarted server used:

```text
PID 50940
```

The service performed the same function, but the restart created a **new process instance**.

---

# Useful Command Reference

| Engineering Question | Command |
|---|---|
| Find a process from a known command/name | `ps aux \| grep http.server` |
| Inspect a known PID's CPU, memory and command | `ps -p <PID> -o pid,%cpu,%mem,command` |
| Inspect network resources associated with port 8080 | `lsof -i :8080` |
| Inspect mapped program code/resources | `lsof -p <PID> \| grep txt` |
| Find a process's current working directory | `lsof -a -p <PID> -d cwd` |
| Check whether a known PID still exists | `ps -p <PID>` |

These commands are **reference material**, rather than syntax that all needs to be reproduced perfectly from memory.

The durable engineering skill is knowing:

> **What evidence do I need, and what system observation can provide that evidence?**

---

# Outcome

This lab demonstrated the ability to:

- Launch a local web service.
- Discover its running process.
- Identify and use its PID.
- Inspect CPU and memory usage.
- Investigate its executable.
- Identify its current working directory.
- Independently verify its listening network socket.
- Deliberately stop the service.
- Prove the process disappeared.
- Prove the listener disappeared.
- Restart the service.
- Verify recovery using a new process and restored listener.

The central operational lesson was:

> **Do not assume the system is in the expected state. Observe it, gather independent evidence, make a prediction, test it, and validate the result.**

---

## Project Status

**Module 01 — Systems — Lab 1: Complete**
