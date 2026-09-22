# Module 01 — Lab 6: Diagnosing Process, Dependency, and PATH Failures

## Business Problem

Bob's Burger Corporation has a small Linux-hosted application that has stopped behaving as expected.

Rather than immediately restarting services, reinstalling packages, or changing configuration, the task was to diagnose several realistic Linux failures using **evidence before action**.

Three fault classes were investigated:

1. An expected process had stopped.
2. A required command/dependency was missing.
3. An executable existed on the machine but could not be resolved through the current `$PATH`.

The lab also demonstrated that a running process, listening port, or even an HTTP response does not automatically prove that the **correct application** is healthy.

## Project Goal

Diagnose and recover multiple Linux application failures using an evidence-first troubleshooting approach:

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

The emphasis was not on memorising Linux commands. The goal was to determine **what evidence was required**, select appropriate system observations, distinguish competing hypotheses, and verify recovery.

---

# Baseline — Establish a Known-Good Service

Before deliberately introducing faults, I created a small application directory:

```bash
mkdir -p ~/bobs-burger-lab6
cd ~/bobs-burger-lab6
```

I created a simple application response:

```bash
cat > index.html <<'EOF'
Bob's Burger Corporation
Service Status: Healthy
EOF
```

The service was started using Python's built-in HTTP server:

```bash
python3 -m http.server 8080 > server.log 2>&1 &
```

The process was then inspected:

```bash
ps aux | grep http.server
```

and the application was exercised directly:

```bash
curl http://localhost:8080
```

Expected response:

```text
Bob's Burger Corporation
Service Status: Healthy
```

This established the known-good state before troubleshooting began.

### Command Recognition

| Part          | Meaning                                                        |
| ------------- | -------------------------------------------------------------- |
| `python3`     | Python 3 interpreter                                           |
| `-m`          | Run a Python module as a program                               |
| `http.server` | Python's built-in HTTP server module                           |
| `8080`        | Port used by the HTTP server                                   |
| `>`           | Redirect standard output                                       |
| `2>&1`        | Send standard error to the same destination as standard output |
| `&`           | Run the command in the background                              |

---

# Fault 1 — Stopped Application Process

## Introduce the Fault

The HTTP-server process was deliberately terminated.

A process search was then performed:

```bash
ps aux | grep http.server
```

The expected Python server process was absent.

Only the `grep` process appeared in the search output.

This provided evidence that the application process itself was no longer running.

---

## Investigate the Network Resource

I wanted additional evidence about the service's expected network state.

The intended command was:

```bash
lsof -i :8080
```

However, instead of returning information about port `8080`, Bash reported:

```text
-bash: lsof: command not found
```

This created a second troubleshooting problem during the first investigation.

Rather than immediately installing `lsof`, I investigated why the command could not be executed.

---

# Fault 2 — Missing Dependency / Command

## Symptom

Running:

```bash
lsof -i :8080
```

returned:

```text
-bash: lsof: command not found
```

A `command not found` message does not by itself prove that software is not installed.

At this point there were at least two relevant hypotheses:

```text
command not found
       ↓
   ┌───┴──────────────┐
   ↓                  ↓
Executable         Executable exists
absent             but cannot be resolved
                   through current $PATH
```

The next step was therefore to collect evidence rather than immediately change the system.

---

## Test Command Resolution

I checked whether the shell could resolve `lsof` through the current `$PATH`:

```bash
which lsof
```

The result showed that `lsof` could not be found in the directories being searched.

This proved that the command was **not currently resolvable through `$PATH`**, but it still did not prove that the executable was absent from the wider filesystem.

---

## Search the Filesystem

I attempted to locate the executable more broadly:

```bash
sudo find / -type f -name lsof
```

No matching regular file was returned.

Combined with the previous evidence:

```text
lsof
   ↓
command not found
   ↓
which lsof
   ↓
not resolvable through $PATH
   ↓
filesystem search
   ↓
no matching executable found
```

the evidence supported the conclusion that `lsof` was absent from this environment rather than simply located outside the current `$PATH`.

---

## Install the Missing Tool

Amazon Linux 2023 uses DNF for package management.

I installed `lsof` using:

```bash
sudo dnf install lsof
```

DNF installed `lsof` and automatically resolved an additional package dependency required by the installation.

This demonstrated another useful distinction:

> A missing command can be a **software/dependency problem**, but that conclusion should follow evidence rather than being assumed from `command not found`.

---

# Validate the Dependency Fix

After installation, I tested command resolution again:

```bash
which lsof
```

Observed:

```text
/usr/bin/lsof
```

This demonstrated that Bash could now resolve the `lsof` command through the current `$PATH`.

The relevant relationship was:

```text
DNF installs lsof
        ↓
Executable placed in /usr/bin
        ↓
/usr/bin was already in $PATH
        ↓
Bash can resolve "lsof"
```

Installing `lsof` did **not** require the kernel to add something to `$PATH`.

Instead, the executable was installed into a directory that was already included in the shell's search path.

---

## Validate Port State

I then ran:

```bash
lsof -i :8080
```

No entries were returned.

At that observation point, the HTTP server had already been terminated, so this was expected.

The command was now functioning correctly, but there was no process holding a matching network resource on port `8080`.

### Important Distinction

`lsof -i :8080` does not show all network traffic flowing through port `8080`.

It identifies relevant **open network resources/sockets held by processes**.

---

# Recover the Stopped Service

With the missing diagnostic tool fixed, I returned to the original application failure.

The intended recovery was:

```text
Stopped application process
        ↓
Restart process
        ↓
Verify process/network state
        ↓
Exercise application
        ↓
Verify expected response
```

The Python server was restarted.

I then inspected port `8080`:

```bash
lsof -i :8080
```

Observed:

```text
COMMAND   PID     USER      FD   TYPE   DEVICE   SIZE/OFF   NODE   NAME
python3   19313   ec2-user  3u   IPv4   ...      0t0        TCP    *:webcache (LISTEN)
```

This demonstrated that a Python process had a TCP socket listening on the expected port.

---

# An Unexpected Validation Failure

I then exercised the application:

```bash
curl http://localhost:8080
```

An HTTP response was returned, but instead of Bob's expected application response, the server returned a directory listing containing entries such as:

```text
.bash_history
.bash_profile
.ssh/
server.log
```

This exposed an important problem.

At this stage:

```text
Process running       ✅
Port 8080 listening   ✅
HTTP responding       ✅
Correct application   ❌
```

The service infrastructure was responding, but the expected application behaviour had **not** been restored.

---

# Investigate the Wrong Application Response

The Python server had been started while the shell was in the home directory:

```text
~
```

Python's simple HTTP server was therefore serving that directory.

Moving the shell afterwards into:

```text
~/bobs-burger-lab6
```

did not change the current working directory of the already-running process.

This reinforced an earlier systems concept:

> A running process has its own runtime state, including its current working directory. Changing the shell's working directory does not retroactively change the working directory of another existing process.

---

# Correct Recovery

The incorrectly started server process was terminated:

```bash
kill 19313
```

The service was then started again from:

```text
~/bobs-burger-lab6
```

using:

```bash
python3 -m http.server 8080 > server.log 2>&1 &
```

The new process received:

```text
PID 19510
```

A process search confirmed it was running:

```bash
ps aux | grep http.server
```

Observed:

```text
ec2-user  19510  ...  python3 -m http.server 8080
```

The application was then exercised again:

```bash
curl http://localhost:8080
```

This time the response was:

```text
Bob's Burger Corporation
Service Status: Healthy
```

The recovery was therefore validated at the application layer.

---

# Service-Health Mental Model

This investigation demonstrated that different observations prove different things:

```text
Expected process exists
        ↓
Process-level evidence
        ↓
Expected network resource exists
        ↓
Port/socket evidence
        ↓
Application accepts request
        ↓
Application-level evidence
        ↓
EXPECTED response returned
        ↓
Expected behaviour validated
```

A process merely existing does not prove application health.

A port merely listening does not prove application health.

Even receiving **an HTTP response** does not necessarily prove that the correct application is healthy.

The response itself must be compared against the expected behaviour.

---

# Fault 3 — Executable Exists but `$PATH` Is Wrong

The final investigation deliberately created the opposite condition to the missing `lsof` executable.

This time:

> The executable would definitely exist, but Bash would initially be unable to resolve its command name.

---

## Create a Diagnostic Tool

A custom tools directory was created:

```bash
mkdir -p ~/bobs-burger-lab6/tools
```

A small executable diagnostic script was created inside it:

```bash
printf '#!/bin/bash\necho "Bob'\''s diagnostic tool: OK"\n' > ~/bobs-burger-lab6/tools/bobs-diagnostic
```

Executable permission was granted:

```bash
chmod +x ~/bobs-burger-lab6/tools/bobs-diagnostic
```

The filesystem entry was inspected:

```bash
ls -l ~/bobs-burger-lab6/tools/bobs-diagnostic
```

Observed:

```text
-rwxr-xr-x. 1 ec2-user ec2-user ... /home/ec2-user/bobs-burger-lab6/tools/bobs-diagnostic
```

This established two pieces of known-good evidence:

* The file existed.
* The file had executable permission.

---

# Test Command Resolution

I attempted to execute the tool using only its command name:

```bash
bobs-diagnostic
```

Bash returned:

```text
-bash: bobs-diagnostic: command not found
```

Because the executable was known to exist, this immediately differed from the earlier `lsof` investigation.

However, I still gathered evidence before changing `$PATH`.

---

# Prove the Executable Exists

To reproduce how the problem could be approached without already knowing where the tool was located, I searched the filesystem:

```bash
sudo find / -type f -name bobs-diagnostic
```

Observed:

```text
/home/ec2-user/bobs-burger-lab6/tools/bobs-diagnostic
```

The executable therefore existed on the machine.

---

# Test `$PATH` Resolution

I then checked whether Bash could resolve the command through the current `$PATH`:

```bash
which bobs-diagnostic
```

Observed:

```text
/usr/bin/which: no bobs-diagnostic in (/home/ec2-user/.local/bin:/home/ec2-user/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin)
```

The executable was located in:

```text
/home/ec2-user/bobs-burger-lab6/tools
```

but that directory was absent from the current `$PATH`.

The evidence chain was therefore:

```text
bobs-diagnostic
        ↓
command not found
        ↓
Filesystem search
        ↓
Executable EXISTS
        ↓
Check command resolution
        ↓
Not resolvable through current $PATH
        ↓
Inspect directories being searched
        ↓
tools/ directory absent
        ↓
PATH-resolution problem
```

---

# `$PATH` Mental Model

`$PATH` is an environment variable containing an **ordered, colon-separated list of directories** used by the shell when resolving command names.

Conceptually:

```text
You type:
bobs-diagnostic
        ↓
Bash receives command name
        ↓
Bash examines $PATH
        ↓
Searches listed directories in order
        ↓
Looks for matching executable
        ↓
If found → command can be launched
If not   → command not found
```

A useful precision distinction is:

> The executable itself is not added to `$PATH`.

Instead:

> The **directory containing the executable** is added to `$PATH`.

---

# Executable Permission vs Command Resolution

This lab separated two mechanisms that can easily be confused:

```text
chmod +x
   ↓
Does this file have
permission to execute?


$PATH
   ↓
Can Bash find the executable
from its bare command name?
```

These are independent.

Running:

```bash
chmod +x bobs-diagnostic
```

does **not** add its directory to `$PATH`.

Similarly, placing a directory in `$PATH` does not itself grant executable permission to files inside that directory.

---

# Fix the `$PATH` Problem

The custom tools directory was temporarily prepended to `$PATH`:

```bash
export PATH="/home/ec2-user/bobs-burger-lab6/tools:$PATH"
```

Conceptually:

```text
Before:

A : B : C : D


After:

~/bobs-burger-lab6/tools : A : B : C : D
            ↑
      searched first
```

The existing `$PATH` was preserved by including:

```bash
$PATH
```

on the right-hand side.

This changed the current shell environment rather than permanently configuring the system.

---

# Validate the `$PATH` Fix

I checked command resolution again:

```bash
which bobs-diagnostic
```

Observed:

```text
~/bobs-burger-lab6/tools/bobs-diagnostic
```

The command name could now be resolved through `$PATH`.

I then executed it:

```bash
bobs-diagnostic
```

Observed:

```text
Bob's diagnostic tool: OK
```

The complete transition was:

```text
Executable exists
        ↓
Executable permission present
        ↓
Directory absent from $PATH
        ↓
Bare command fails
        ↓
Add containing directory to $PATH
        ↓
Command resolves
        ↓
Executable runs successfully
```

---

# Missing Executable vs PATH Failure

The two `command not found` investigations provided a useful comparison.

## `lsof`

```text
command not found
        ↓
Not resolvable through $PATH
        ↓
Filesystem search
        ↓
Executable absent
        ↓
Install missing package
        ↓
Validate command resolution
```

## `bobs-diagnostic`

```text
command not found
        ↓
Filesystem search
        ↓
Executable exists
        ↓
Not resolvable through $PATH
        ↓
Containing directory absent from $PATH
        ↓
Update $PATH
        ↓
Validate command resolution
```

Therefore:

> **`command not found` is a symptom, not a root cause.**

---

# Live-System Troubleshooting Mental Model

The complete lab can be reduced to one operational principle:

```text
Something fails
      ↓
Do NOT immediately change configuration
      ↓
Observe the system
      ↓
Gather evidence
      ↓
Identify plausible explanations
      ↓
Test those explanations
      ↓
Determine the root cause
      ↓
Make the smallest justified fix
      ↓
Validate expected behaviour
```

The exact troubleshooting labels do not need to be memorised word-for-word.

The durable engineering behaviour is:

> **Use evidence to understand the failure before changing the system, then prove that the fix restored the expected behaviour.**

---

# Engineering Lessons Learned

## 1. `command not found` Is Not a Diagnosis

A shell reporting:

```text
command not found
```

does not automatically mean:

```text
install the package
```

Relevant possibilities include:

* the executable is genuinely absent;
* the executable exists but cannot be resolved through the current `$PATH`.

Evidence should distinguish those possibilities before making changes.

---

## 2. `$PATH` Contains Directories, Not Executable Files

The clean mental model is:

> **The shell tries to resolve a command name by searching the directories listed in `$PATH`.**

The directory containing an executable can be added to `$PATH`.

The executable itself is not added to `$PATH`.

---

## 3. Executable Permission and Command Resolution Are Different

A file can:

```text
Exist               ✅
Be executable       ✅
Resolve via $PATH   ❌
```

This was exactly the state of `bobs-diagnostic` before the `$PATH` fix.

---

## 4. Process State Does Not Prove Application Health

A running process proves that a process exists.

It does not prove that the application is performing its intended function.

---

## 5. A Listening Port Does Not Prove Application Health

A listening socket proves that something is prepared to receive connections on that network resource.

It does not prove that the correct application behaviour is available.

---

## 6. Any HTTP Response Is Not Enough

During recovery:

```text
Process running       ✅
Port listening        ✅
HTTP response          ✅
Correct application   ❌
```

The Python server was serving the wrong directory.

Validation therefore needed to check the **expected application response**, not simply whether HTTP returned something.

---

## 7. Running Processes Retain Their Own Working Directory

Changing the shell from:

```text
~
```

to:

```text
~/bobs-burger-lab6
```

did not change the working directory of the already-running Python process.

The incorrect process had to be terminated and a new process started from the intended application directory.

---

## 8. Validate Every Important State Transition

The lab repeatedly followed this principle:

```text
Make change
   ↓
Do not assume success
   ↓
Collect evidence
   ↓
Compare actual state with expected state
```

This caught the incorrectly started Python server even though it was running, listening, and responding to HTTP.

---

# Useful Command Reference

| Engineering Question                                             | Command                                  |
| ---------------------------------------------------------------- | ---------------------------------------- |
| Find the HTTP-server process                                     | `ps aux \| grep http.server`             |
| Check whether a known PID exists                                 | `ps -p <PID>`                            |
| Inspect network resources associated with port `8080`            | `lsof -i :8080`                          |
| Test the local HTTP application                                  | `curl http://localhost:8080`             |
| Check what executable the current `$PATH` resolves for a command | `which <command>`                        |
| Search the filesystem for a regular file with an exact name      | `sudo find / -type f -name <name>`       |
| Display the current `$PATH`                                      | `echo $PATH`                             |
| Temporarily prepend a directory to `$PATH`                       | `export PATH="/path/to/directory:$PATH"` |
| Give a file executable permission                                | `chmod +x <file>`                        |
| Stop a known process                                             | `kill <PID>`                             |
| Install a package on Amazon Linux 2023                           | `sudo dnf install <package>`             |

These commands are reference material.

The durable engineering skill is knowing:

> **What am I trying to prove, what evidence would distinguish my hypotheses, and how will I validate the expected behaviour after the fix?**

---

# Outcome

This lab demonstrated the ability to:

* Establish a known-good application state before introducing faults.
* Diagnose an expected process that had stopped.
* Verify process and network state independently.
* Investigate `command not found` rather than immediately installing software.
* Distinguish a missing executable from a `$PATH` resolution problem.
* Understand `$PATH` as an ordered list of directories searched by the shell.
* Separate executable permissions from command resolution.
* Install a genuinely missing Linux command using DNF.
* Validate that an installed command became resolvable.
* Create and execute a custom diagnostic tool.
* Diagnose an executable that existed but was outside the current `$PATH`.
* Temporarily modify `$PATH` and validate the result.
* Recognise that process existence does not prove application health.
* Recognise that a listening socket does not prove application health.
* Recognise that even an HTTP response may come from the wrong application state.
* Identify a wrong working directory as the cause of incorrect HTTP content.
* Restart the application from the correct working directory.
* Validate recovery using the **expected application response**.

The central operational lesson was:

> **A symptom tells you where to begin investigating, not what to fix. Gather evidence, distinguish plausible causes, make the smallest justified change, and validate the behaviour that actually matters.**

---

## Project Status

**Module 01 — Systems — Lab 6**
