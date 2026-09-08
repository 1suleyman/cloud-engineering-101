# Module 01 — Lab 3: Tracing an Executable from Storage to Observable Output

## Business Problem

Bob's Burger Corporation wants its junior cloud engineers to understand what actually happens between having an application installed on a computer and seeing that application perform useful work.

A teammate makes the assumption:

> "The file is on disk, so the computer can run it."

The task was to test that assumption by tracing a real Python executable from its filesystem path through a running process, RAM and CPU activity, and finally to observable application output.

The investigation used operating-system evidence rather than treating the presence of a file on storage as proof that an application was running.

## Project Goal

Trace one executable through the following dependency chain:

```text
Executable on storage
        ↓
Filesystem path
        ↓
Operating system starts the program
        ↓
Running process
        ↓
RAM + CPU execution
        ↓
Application performs work
        ↓
Observable output
```

---

# Investigation

## Locate the Stored Executable

I first identified which Python executable the shell would resolve:

```bash
which python3.13
```

Observed:

```text
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

I then inspected the filesystem entry:

```bash
ls -l /Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

Observed:

```text
-rwxrwxr-x 1 root admin 119424 11 Jun 2025 python3.13
```

This provided filesystem evidence that the Python executable existed on storage.

### Evidence Interpretation

The beginning of the output:

```text
-rwxrwxr-x
```

showed that this was a regular filesystem entry with executable permissions.

The relevant fields included:

```text
-rwxrwxr-x  1  root  admin  119424  11 Jun 2025  python3.13
     │       │    │     │       │          │           │
 permissions │  owner group    size      modified     name
             │
           links
```

The leading:

```text
-
```

indicated a regular file.

The `x` permission indicated executable permission for the corresponding permission classes.

---

## Command Resolution vs File Existence

The investigation also reinforced an important distinction:

```bash
which python3.13
```

answers approximately:

> Which executable would my current shell resolve for this command through its current `PATH`?

It is not a universal search of the computer's storage.

Therefore:

```text
which returns a path
        ↓
command is resolvable through the current PATH

which returns nothing
        ↓
command was not resolved through the current PATH
        ≠
proof that the file does not exist anywhere on storage
```

This distinction becomes important when troubleshooting applications that are installed but cannot be launched by name.

---

# Start the Application

I launched Python's built-in HTTP server:

```bash
python3 -m http.server 8080
```

This created a running Python process configured to serve HTTP traffic on port `8080`.

The important distinction was now:

```text
Python executable
stored on filesystem
        ↓
Operating system starts it
        ↓
Running Python process
```

The stored executable and the running process were related, but they were not the same thing.

---

# Identify the Running Process

I searched the process table:

```bash
ps aux | grep http.server
```

The HTTP server was identified as:

```text
PID 6001
```

The output also contained the `grep` process because:

```bash
grep http.server
```

was itself a running process whose command line contained the search term.

### Evidence Established

At this point I had independently observed:

```text
Stored executable
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
        ↓
Running process
PID 6001
```

This demonstrated why simply proving that an executable exists on storage does not prove that an application is currently running.

---

# Observe RAM and CPU State

Once the PID was known, I inspected that specific process:

```bash
ps -p 6001 -o pid,%cpu,%mem,command
```

Observed:

```text
PID   %CPU  %MEM  COMMAND
6001  0.0   0.1   /Library/Frameworks/Python.framework/Versions/3.13/Resources...
```

At that observation point:

- **PID:** `6001`
- **CPU:** `0.0%`
- **Memory:** `0.1%`
- **Process:** Python HTTP server

The process therefore existed as a running operating-system process and occupied memory even though it was using effectively no measurable CPU at that instant.

---

# Idle Does Not Mean Stopped

The `0.0%` CPU observation initially raises an important systems question:

> How can a process be running if it is using 0.0% CPU?

A running process does not need to execute continuously.

The HTTP server was alive but mostly waiting for work.

It could still retain runtime resources such as:

```text
Process / PID
      ↓
Memory
      ↓
Network socket
      ↓
Working directory
      ↓
Other OS-managed resources
```

while consuming effectively no measurable CPU during the observation window.

Therefore:

```text
0.0% CPU
```

did **not** mean:

```text
process terminated
```

It meant that the process was not consuming measurable CPU at that observation point.

---

# Give the Process Work

To move from an idle process to observable application activity, I generated an HTTP request:

```bash
curl http://localhost:8080
```

For this lab, the useful mental model for `curl` was simply:

> `curl` acted as a command-line client that sent a request to a URL and displayed the response.

There was no need to learn the deeper internals of `curl` to understand the systems dependency chain.

### Request Path

```text
curl
  ↓
HTTP request
  ↓
localhost
  ↓
Port 8080
  ↓
Existing Python server process
```

The command did not create another HTTP server.

Instead, it gave the **existing server process** work to perform.

---

# Observe the Server Handling the Request

The server terminal recorded:

```text
::1 - - [04/Sep/2026 19:12:48] "GET / HTTP/1.1" 200 -
```

This provided evidence that the running server had received and handled the request.

Important parts included:

```text
GET /
```

The client requested the root resource.

```text
HTTP/1.1
```

The request used HTTP.

```text
200
```

The server returned a successful HTTP response.

The server was therefore not merely present as a process. It had performed useful application work.

---

# Observe the Application Output

The `curl` command displayed an HTML directory listing.

This was the response body returned by the Python HTTP server.

The complete observed interaction was therefore:

```text
curl acts as client
        ↓
HTTP request sent to localhost:8080
        ↓
Existing Python server process receives work
        ↓
CPU executes instructions as required
        ↓
Server handles GET /
        ↓
HTTP 200 response
        ↓
HTML response body
        ↓
curl displays the HTML
```

This connected the operating-system process model to observable application behaviour.

---

# Why the Directory Listing Appeared

The Python HTTP server had been started from the user's current directory.

The HTTP server therefore served content from that filesystem context.

When the client requested:

```text
/
```

the server generated an HTML directory listing representing the directory it was serving.

This also connected an earlier systems concept — the **current working directory** — to real application behaviour.

A process's filesystem context can directly affect what an application does.

---

# Complete Dependency Chain

The main objective of the lab was to connect all of the individual systems components into one model:

```text
STORAGE
Python executable exists as a file
        ↓
FILESYSTEM
Provides the path and metadata used to locate the executable
        ↓
OPERATING SYSTEM
Creates and manages a running process from the program
        ↓
PROCESS
PID 6001 represents this running instance
        ↓
RAM
Holds the process's active runtime state and required code/data
        ↓
CPU
Executes instructions when the process is scheduled to perform work
        ↓
APPLICATION WORK
HTTP request is received and processed
        ↓
OUTPUT
HTTP 200 + HTML response
```

An important precision point is that this does **not** require assuming that the entire executable is copied into RAM before execution.

The operating system loads/maps the code and data required for execution, and the CPU executes instructions from memory/cache as required.

---

# Stored State vs Runtime State

This lab made the distinction between persistent and runtime state clearer.

## Exists on Storage

Examples included:

```text
Python executable
Filesystem path
Program files
```

These can remain present when the application is not running.

## Exists as Part of Runtime

Examples included:

```text
PID 6001
Running process
Runtime memory
Active CPU execution
Open runtime resources
```

These depend on a running process.

This explains why:

> **"The program is installed" and "the application is running" are two different claims requiring different evidence.**

---

# Evidence Map

Different observations answered different engineering questions:

| Engineering Question | Evidence |
|---|---|
| Where is the executable resolved from? | `which python3.13` |
| Does that filesystem entry exist? | `ls -l <path>` |
| Is the HTTP server actually running? | `ps aux \| grep http.server` |
| Which process instance is it? | PID `6001` |
| What CPU/memory state does it currently have? | `ps -p 6001 -o pid,%cpu,%mem,command` |
| Can the running application actually perform work? | `curl http://localhost:8080` |
| Did the server handle the request successfully? | Server log showing `GET /` and HTTP `200` |
| What output did the application produce? | HTML response displayed by `curl` |

The important skill was not memorising every command flag.

It was knowing:

> **What claim am I trying to prove, and what evidence would actually prove it?**

---

# Engineering Lessons Learned

## 1. A File Existing Does Not Mean the Application Is Running

An executable can exist on storage while there are zero running instances of it.

Filesystem evidence and process evidence answer different questions.

---

## 2. A Process Is a Runtime Instance

Starting the Python HTTP server created a running process with:

```text
PID 6001
```

The PID identified that particular runtime instance rather than the stored Python executable itself.

---

## 3. RAM and CPU Have Different Roles

The running process occupied memory while using:

```text
0.0% CPU
```

at one observation point.

RAM can hold the process's active runtime state while the process waits.

CPU usage occurs when instructions actually need to execute.

---

## 4. Idle Is Not the Same as Dead

A server can spend much of its life waiting for events.

When no request was arriving, the HTTP server required effectively no measurable CPU at the observation point.

When a request arrived, the existing process had work to perform.

---

## 5. Events Cause Processes to Perform Work

The HTTP request provided an observable trigger:

```text
Idle server
     ↓
Request arrives
     ↓
Process receives work
     ↓
CPU executes instructions
     ↓
Response produced
```

This is a more useful model than imagining a running process as continuously consuming CPU.

---

## 6. Output Completes the Systems Chain

The returned HTML was not an isolated application detail.

It was the observable result of the complete dependency chain:

```text
storage
→ filesystem
→ operating system
→ process
→ RAM
→ CPU execution
→ application work
→ output
```

---

## 7. Diagnose Claims with the Correct Evidence

Different system claims require different observations.

```text
"Python is installed"
        ↓
filesystem / PATH evidence

"The server is running"
        ↓
process evidence

"The process has runtime state"
        ↓
memory/process evidence

"The application works"
        ↓
request + response evidence
```

No single observation proves every layer.

---

# Useful Command Reference

| Engineering Question | Command |
|---|---|
| Find which executable the shell resolves | `which python3.13` |
| Inspect the executable's filesystem metadata | `ls -l <path>` |
| Start the local HTTP server | `python3 -m http.server 8080` |
| Discover the running server process | `ps aux \| grep http.server` |
| Inspect a known PID's CPU/memory state | `ps -p <PID> -o pid,%cpu,%mem,command` |
| Send an HTTP request to the local service | `curl http://localhost:8080` |

These commands are reference material.

The durable engineering skill is understanding the question each command helps answer and interpreting the evidence it returns.

---

# Live-System Mental Model

```text
┌─────────────────────────────┐
│          STORAGE            │
│                             │
│  Python executable exists   │
│  as persistent program data │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│         FILESYSTEM          │
│                             │
│  Provides path + metadata   │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│      OPERATING SYSTEM       │
│                             │
│  Creates/manages process    │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│       PROCESS 6001          │
│                             │
│  Running Python HTTP server │
└──────────┬─────────┬────────┘
           │         │
           ↓         ↓
          RAM       CPU
           │         │
           │         ↓
           │    Executes work
           │    when required
           │         │
           └────┬────┘
                ↓
          HTTP GET /
                ↓
          HTTP 200
                ↓
         HTML response
```

---

# Outcome

This lab demonstrated the ability to:

- Locate a real executable through its filesystem path.
- Inspect the executable as a stored filesystem object.
- Distinguish shell command resolution from general file existence.
- Start the program and identify its running process.
- Relate a stored executable to a specific PID.
- Observe the process's CPU and memory state.
- Explain why an idle process can remain running with effectively no measurable CPU usage.
- Generate work for the process using an HTTP request.
- Observe the server handling that request.
- Interpret an HTTP `200` response as successful handling of the request.
- Observe the resulting HTML output.
- Explain where storage, filesystem, operating system, process, RAM, and CPU each fit in the execution path.

The central systems lesson was:

> **A program existing on storage is only the beginning. To produce useful output, the operating system must create and manage a process, the process requires runtime state in memory, the CPU executes its instructions when work is required, and the resulting behaviour must be verified from observable evidence.**

---

## Project Status

**Module 01 — Systems — Lab 3: Complete**
