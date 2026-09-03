# Module 01 — Lab 2: Investigating the Program-to-Process Relationship

## Business Problem

Bob's Burger Corporation has an application installed on a system, but customers cannot currently use it.

A junior cloud engineer needs to determine whether the application being **installed on storage** means that it is actually **running**, and understand what happens when multiple running instances are created from the same stored program.

The task was to inspect the Python installation on storage, compare it with zero, one, and two running HTTP-server processes, deliberately create a port conflict, terminate one process, and prove that the underlying stored program still existed.

## Project Goal

Build and verify the relationship between:

```text
Stored program
      ↓
Running process
```

Then prove that:

- A program can exist on storage while no corresponding HTTP-server process is running.
- One stored program can create multiple independent running processes.
- Each process receives its own PID and runtime state.
- Multiple processes cannot normally bind the same local IP + protocol + port combination.
- Terminating a process does not delete the stored program it came from.

---

# Investigation

## Establish the Stored Program

Before starting the HTTP server, I first investigated the Python program available on the system.

```bash
which python3
```

Observed:

```text
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3
```

`which` showed the filesystem path that the shell resolved for the `python3` command through the current `PATH`.

This provided evidence that `python3` was available to the shell, but it did not by itself describe the filesystem entry.

---

## Inspect the Python Filesystem Entry

I inspected the resolved path:

```bash
ls -l /Library/Frameworks/Python.framework/Versions/3.13/bin/python3
```

Observed:

```text
lrwxrwxr-x  1 root  admin  10 25 Jun 2025 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 -> python3.13
```

The leading:

```text
l
```

and:

```text
python3 -> python3.13
```

showed that `python3` was a **symbolic link** pointing to `python3.13`.

### Symbolic-Link Mental Model

A symbolic link is a filesystem entry that references another filesystem path.

In this installation:

```text
python3
   ↓
symbolic link
   ↓
python3.13
```

This is a filesystem mechanism rather than something specific to Python. Similar patterns can appear with runtimes, command-line tools, application versions, libraries, and other software.

---

## Inspect the Symlink Target

I then located the target command:

```bash
which python3.13
```

Observed:

```text
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

I inspected that filesystem entry:

```bash
ls -l /Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

Observed:

```text
-rwxrwxr-x  1 root  admin  119424 11 Jun 2025 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

The leading:

```text
-
```

showed that this filesystem entry was a **regular file**.

The `x` permission bits showed that the file had **execute permissions**.

The observed resolution chain was therefore:

```text
python3 command
      ↓
shell resolves command through PATH
      ↓
python3 filesystem entry
      ↓
symbolic link
      ↓
python3.13
      ↓
regular executable file
```

This provided direct filesystem evidence that the Python program existed independently of whether an HTTP-server process was currently running.

> **Precision note:** If `which python3` or `which python3.13` returned `not found`, this would mean that the shell could not resolve that command through the current `PATH`. It would not by itself prove that no corresponding executable existed anywhere on storage.

---

# Zero-Process State

At this stage, the Python executable existed on storage, but the previous HTTP-server process from Lab 1 was no longer running.

This established the first important distinction:

```text
Program exists on storage
        ≠
Process currently running
```

A **program** consists of persistent executable/code files stored on storage.

A **process** is a running instance created when a program is executed.

The existence of one does not imply the current existence of the other.

---

# Create One Running Process

I started one Python HTTP server:

```bash
python3 -m http.server 8080
```

Python reported:

```text
Serving HTTP on :: port 8080 ...
```

I then independently inspected the operating-system process state:

```bash
ps aux | grep http.server
```

The server process was identified as:

```text
PID 73296
```

with a command containing:

```text
Python -m http.server 8080
```

This established the **one-process state**:

```text
Python program on storage
        ↓
     executed
        ↓
HTTP-server process
    PID 73296
    port 8080
```

The stored program had not transformed into the process or disappeared from storage.

Instead, executing the program resulted in a new runtime process instance.

---

# Controlled Break/Fix — Port Conflict

## Prediction

The next objective was to create a second HTTP-server process from the same stored Python program.

Initially, I attempted to start another server using exactly the same command:

```bash
python3 -m http.server 8080
```

This raised an important engineering question:

> Can two separate processes listen using the same local network endpoint simply because they have different PIDs?

---

## Introduce the Fault

The second process attempted to start but failed.

Python returned:

```text
OSError: [Errno 48] Address already in use
```

The traceback showed that the failure occurred when the server attempted to bind its socket:

```text
self.socket.bind(self.server_address)
```

This provided evidence that the problem was not the Python program itself.

The first process had already successfully bound a listening socket using port `8080`.

---

# Investigating the Port Conflict

The failure exposed an important networking relationship.

Under the normal case investigated in this lab, another process cannot independently bind and listen using the same local:

```text
IP address
    +
transport protocol
    +
port
```

combination when that listening endpoint is already occupied.

For example:

```text
Process A
   ↓
Local IP + TCP + 8080
   ↓
LISTENING
```

A second process attempting the same combination:

```text
Process B
   ↓
Local IP + TCP + 8080
   ↓
Address already in use
```

is rejected by the operating system.

### Important Distinction

This behaviour is **not specific to Python** or to Python's `http.server` module.

Changing the implementation to Java, Node.js, or another technology would not normally allow another process to independently bind the exact same local listening endpoint.

The operating system manages network sockets.

---

## Why Port Numbers Can Be Reused Elsewhere

The port number alone does not globally identify a network listener.

For example, two different machines can both provide HTTPS using TCP port `443`:

```text
192.168.1.10 : TCP : 443
192.168.1.20 : TCP : 443
```

The different IP addresses distinguish the listening endpoints.

Therefore:

> Port `8080` is not globally owned by one process everywhere.

The conflict observed in this lab concerned processes attempting to use the same local IP + protocol + port combination.

> **Scope note:** There are more advanced socket behaviours and exceptions, but they were intentionally outside the scope of this lab. The objective here was to establish the operational model needed for process and network troubleshooting.

---

# Create Two Running Processes

To remove the conflict, I changed the second server's listening port:

```bash
python3 -m http.server 8081
```

Python reported:

```text
Serving HTTP on :: port 8081 ...
```

I then searched the process table:

```bash
ps aux | grep http.server
```

The relevant output showed:

```text
PID 73296  ... Python -m http.server 8080
PID 74077  ... Python -m http.server 8081
```

A third matching process appeared temporarily:

```text
PID 74081  ... grep http.server
```

This was the `grep` process itself rather than another HTTP server.

The evidence therefore established:

```text
One stored Python program
          ↓
     ┌────┴────┐
     ↓         ↓
Process A   Process B
PID 73296   PID 74077
port 8080   port 8081
```

The two different PIDs proved that these were **separate process instances**.

---

# Program-to-Process Relationship

This experiment demonstrated that the relationship between a stored program and running processes is not one-to-one.

One stored program can give rise to multiple running process instances:

```text
             Python program
             stored on disk
                   ↓
             ┌─────┴─────┐
             ↓           ↓
        Process A     Process B
        PID 73296     PID 74077
        own state     own state
        port 8080     port 8081
```

Each process has its own runtime identity and state.

The different ports were resources held by these particular server processes, but the ports themselves were **not what fundamentally made the processes independent**.

The distinct PIDs demonstrated separate process identities.

---

# Terminate One Process

I deliberately terminated the second HTTP-server process running on port `8081` using:

```text
Ctrl+C
```

Python reported:

```text
Keyboard interrupt received, exiting.
```

The terminated process had been:

```text
PID 74077
```

Rather than assuming that only this process had stopped, I inspected the process table again:

```bash
ps aux | grep http.server
```

The remaining server was:

```text
PID 73296  ... Python -m http.server 8080
```

PID `74077` was absent.

The other matching entry:

```text
grep http.server
```

was only the temporary search process.

This proved:

```text
Process A — PID 73296 → still running
Process B — PID 74077 → terminated
```

Terminating one process did not terminate the other process, even though both originated from the same stored Python program.

---

# Prove the Stored Program Still Exists

The final competency requirement was to prove that terminating a process had **not deleted the underlying stored program**.

I again resolved the Python executable:

```bash
which python3.13
```

Observed:

```text
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

I then directly inspected the filesystem entry:

```bash
ls -l /Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

Observed:

```text
-rwxrwxr-x  1 root  admin  119424 11 Jun 2025 /Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13
```

The regular executable file still existed on storage.

The complete observed lifecycle was therefore:

```text
Python executable exists on storage
              ↓
      zero HTTP-server processes
              ↓
      start first instance
              ↓
        PID 73296 :8080
              ↓
      attempt second :8080
              ↓
     Address already in use
              ↓
      change second to :8081
              ↓
       ┌──────┴──────┐
       ↓             ↓
PID 73296 :8080   PID 74077 :8081
       ↓             ↓
       │        terminate process
       │             ↓
       │        PID 74077 gone
       ↓
PID 73296 remains
              ↓
Python executable still exists on storage
```

---

# Live-System Mental Model

The lab established the following systems model:

```text
                    STORAGE
                       │
                       │
              Python executable
                       │
              executed as needed
                       │
             ┌─────────┴─────────┐
             ↓                   ↓
         PROCESS A           PROCESS B
         PID 73296           PID 74077
             │                   │
      runtime state         runtime state
             │                   │
       TCP :8080             TCP :8081
             │
        remains alive

                   PROCESS B
                       ↓
                  terminated

                       BUT

                Python executable
                remains on storage
```

The stored program and its running processes therefore have **separate lifecycles**.

---

# Engineering Lessons Learned

## 1. A Program Is Not a Process

A program is persistent executable/code stored on storage.

A process is a running instance created through execution of a program.

Therefore:

```text
Program exists
     ≠
Process running
```

A system can have an application installed while having no currently running process for that application.

---

## 2. One Program Can Create Multiple Processes

The same stored Python program produced:

```text
PID 73296
PID 74077
```

These were independent runtime process instances.

Each had its own PID and runtime state even though they originated from the same stored program.

---

## 3. Process Termination Does Not Mean Program Deletion

Terminating PID `74077` removed that running process instance.

It did not remove:

- PID `73296`
- the Python executable stored on disk

This demonstrates why process lifecycle and filesystem lifecycle must not be confused during troubleshooting.

---

## 4. A PID Identifies a Running Process Instance

Different processes created from the same stored program receive different process IDs.

In this lab:

```text
Python program
    ├── PID 73296
    └── PID 74077
```

The PID identifies the particular running process instance rather than the stored program itself.

---

## 5. Network Ports Are OS-Managed Resources

The failed second `8080` server demonstrated that a process can hold a listening network socket as an operating-system-managed resource.

Attempting to create another listener using the same local IP + protocol + port combination normally results in a conflict:

```text
OSError: [Errno 48] Address already in use
```

Changing the second server to port `8081` removed that conflict.

---

## 6. Symbolic Links Can Reference Other Filesystem Paths

The observed Python installation used:

```text
python3 -> python3.13
```

The `python3` filesystem entry was a symbolic link referencing `python3.13`.

This is a general filesystem concept rather than a Python-specific mechanism.

---

## 7. Evidence Must Match the Question

Different observations answered different engineering questions.

| Engineering Question | Evidence |
|---|---|
| What path does the shell resolve for this command? | `which python3` |
| What kind of filesystem entry is this? | `ls -l <path>` |
| Is an HTTP-server process currently running? | `ps aux \| grep http.server` |
| Are there multiple server process instances? | Compare their PIDs |
| Did terminating one process remove the other? | Inspect the process table again |
| Does the executable still exist on storage? | Directly inspect its filesystem entry |

The important engineering lesson is:

> **Choose evidence based on the claim you are trying to prove.**

---

# Useful Command Reference

| Engineering Question | Command |
|---|---|
| Resolve `python3` through the current `PATH` | `which python3` |
| Inspect a filesystem entry | `ls -l <path>` |
| Resolve the versioned Python command | `which python3.13` |
| Find running HTTP-server processes | `ps aux \| grep http.server` |
| Start an HTTP server on port 8080 | `python3 -m http.server 8080` |
| Start another instance on port 8081 | `python3 -m http.server 8081` |

These commands are reference material rather than syntax that must all be reproduced perfectly from memory.

The durable skill is understanding **what system state each command helps observe**.

---

# Outcome

This lab demonstrated the ability to:

- Distinguish a stored program from a running process.
- Inspect how a shell command maps to an executable on storage.
- Recognise a symbolic link and inspect its target.
- Prove that a program can exist while no corresponding HTTP-server process is running.
- Start a process from the stored Python program.
- Attempt a second process and diagnose a listening-port conflict from evidence.
- Correct the conflict by selecting another listening port.
- Run two independent processes from the same stored program.
- Prove those processes have distinct PIDs.
- Terminate one process while leaving the other running.
- Prove that process termination did not delete the underlying executable.

The central systems lesson was:

> **A program is persistent code stored on storage; a process is a runtime instance of that program. One stored program can create multiple independent processes, and terminating those processes does not delete the program itself.**

The lab also reinforced an operational troubleshooting principle:

> **Do not infer one type of system state from evidence that answers a different question. Decide what you need to prove, then gather evidence that directly tests that claim.**

---

## Project Status

**Module 01 — Systems — Lab 2: Complete**
