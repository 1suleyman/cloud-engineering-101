# Module 01 — Lab 5: Investigating Controlled CPU and Memory Load

## Business Problem

Bob's Burger Corporation has a Linux server that occasionally becomes slow. An engineer reports that the server is "using lots of resources," but that statement alone does not identify which resource is under pressure or explain what is causing it.

The task was to deliberately create controlled CPU and memory workloads and use Linux operating-system evidence to observe how processes consume those resources.

The investigation focused on distinguishing:

* CPU utilisation from load average.
* CPU capacity from runnable CPU demand.
* Completely unused memory from memory realistically available to applications.
* System-wide memory measurements from process-level memory consumption.
* Resource pressure from normal resource usage.

The workloads were then removed so recovery could be independently verified.

## Project Goal

Create controlled CPU and memory pressure on a Linux EC2 instance and build an evidence-based mental model connecting:

```text
Workload changes
        ↓
Process behaviour changes
        ↓
CPU / memory demand changes
        ↓
Linux exposes measurements
        ↓
Engineer interprets evidence
        ↓
Workload removed
        ↓
System recovery verified
```

---

# CPU Investigation

## Establish a Baseline

Before deliberately generating CPU load, I inspected the system using:

```bash
uptime
```

An early baseline showed:

```text
14:15:40 up 19 min, 1 user, load average: 0.00, 0.00, 0.00
```

This established that the system had very little measured load before the controlled workload was introduced.

The three load-average values represent the system's shorter- and longer-term load history:

```text
1-minute
5-minute
15-minute
```

### Key Concept

Load average should **not** be interpreted as CPU utilisation.

For the CPU-bound workloads used in this lab, runnable processes contributed to system load. Linux load average can also include certain tasks in uninterruptible waiting states.

---

## Generate Controlled CPU Load

I generated a continuously CPU-bound workload using:

```bash
yes > /dev/null &
```

The shell returned:

```text
[1] 2742
```

This identified:

* Shell job number: `1`
* Process ID: `2742`

### Command Recognition

| Part        | Meaning                                               |
| ----------- | ----------------------------------------------------- |
| `yes`       | Continuously produces output                          |
| `>`         | Redirect standard output                              |
| `/dev/null` | Special device that accepts and discards written data |
| `&`         | Run the command as a background shell job             |

The purpose was not to perform useful application work. It was to deliberately create a predictable CPU-bound process for observation.

---

## Inspect the CPU-Bound Process

I inspected the process using:

```bash
ps -C yes -o pid,%cpu,%mem,command
```

An observation showed:

```text
PID   %CPU  %MEM  COMMAND
2742  97.8   0.0  yes
```

The process was consuming approximately one logical CPU's worth of CPU time while consuming negligible memory.

### Key Concept

On this Linux system, a single-threaded process reporting approximately:

```text
%CPU ≈ 100
```

was interpreted as consuming roughly **one logical CPU's worth of CPU time**.

It did not necessarily mean the entire machine was at 100% CPU capacity.

---

## Create a Second CPU-Bound Process

I started another independent instance of the same program:

```bash
yes > /dev/null &
```

This produced another process:

```text
PID 2808
```

Both were observed:

```text
PID   %CPU  %MEM  COMMAND
2742  98.9   0.0  yes
2808  104    0.0  yes
```

This reinforced a systems concept from earlier labs:

> One stored program can produce multiple independent running processes.

The value slightly above 100% should not be interpreted as proof that the single-threaded process required more than one logical CPU. Process CPU measurements can vary due to sampling and accounting.

---

## Determine Available CPU Capacity

I checked how many processing units were available:

```bash
nproc
```

Observed:

```text
2
```

The system therefore exposed:

```text
2 logical CPUs
```

For an EC2 instance, **logical CPU / vCPU** is the appropriate model rather than assuming each processing unit corresponds directly to a physical CPU core.

With two continuously CPU-bound processes and two logical CPUs, the system had approximately enough CPU execution capacity for both workloads.

---

## Observe System Load

With the two CPU-bound processes running:

```bash
uptime
```

showed:

```text
load average: 2.03, 1.66, 0.87
```

The 1-minute load average had moved toward approximately `2`.

The 5- and 15-minute values were lower because they retained more influence from the earlier period when the system had little load.

### Important Distinction

```text
CPU utilisation
        ≠
Load average
```

CPU utilisation describes how much CPU execution capacity is being consumed.

Load average reflects the amount of work in states counted by Linux load accounting, including runnable work and certain uninterruptible waiting tasks.

---

# Exceeding Immediate CPU Capacity

## Introduce a Third CPU-Bound Process

The machine had:

```text
2 logical CPUs
```

I then increased the workload to:

```text
3 continuously CPU-bound processes
```

The third process received:

```text
PID 4108
```

An immediate observation showed:

```text
PID   %CPU  %MEM  COMMAND
2742  99.7   0.0  yes
2808  99.7   0.0  yes
4108  91.6   0.0  yes
```

These process-level `%CPU` values were influenced by CPU time accumulated over the processes' lifetimes and therefore were not a clean instantaneous view of how the two logical CPUs were being shared at that exact moment.

---

## Observe Load Under CPU Contention

Initially:

```text
load average: 2.19, 2.05, 1.93
```

After the three CPU-bound processes remained active:

```text
load average: 2.98, 2.55, 2.16
```

The 1-minute load average moved toward approximately:

```text
3
```

This occurred even though the machine had only:

```text
2 logical CPUs
```

### CPU Contention Mental Model

```text
3 runnable CPU-bound processes
            ↓
      2 logical CPUs
            ↓
Only 2 can execute on CPU
at the same instant
            ↓
Additional runnable work can
wait for CPU time
            ↓
Scheduler shares CPU time
between runnable processes
            ↓
Load approaches roughly 3
in this controlled experiment
```

The third process did not require a third CPU to exist.

Instead, the operating system scheduler could distribute CPU time among the runnable processes.

> **Runnable does not mean currently executing.**

---

# Controlled CPU Recovery

One CPU-bound workload was removed, leaving two CPU-bound processes on two logical CPUs.

Repeated observations showed the 1-minute load average falling:

```text
2.85
  ↓
2.66
  ↓
2.61
  ↓
2.17
```

This was consistent with CPU demand moving from approximately three continuously runnable CPU-bound workloads back toward two.

The experiment demonstrated that load average does not naturally rise and then fall simply because time passes.

If the workload remains constant, the shorter-term load should tend toward the workload's new level. It begins falling when the workload contributing to load decreases.

---

# Operational Side Investigation — SSH Sessions

During the sustained CPU experiment, several SSH connections unexpectedly reset:

```text
Connection reset by peer
Broken pipe
```

Rather than assuming CPU pressure was the root cause, I investigated the system state.

I used:

```bash
who
```

and observed four sessions:

```text
ec2-user pts/0
ec2-user pts/1
ec2-user pts/2
ec2-user pts/3
```

All were associated with the same source address.

I then inspected them using:

```bash
w
```

and found that the earlier sessions still had shell processes associated with them.

Finally:

```bash
ps -t pts/0,pts/1,pts/2 -o pid,tty,stat,cmd
```

showed:

```text
PID   TTY    STAT  CMD
2603  pts/0  Ss+   -bash
2742  pts/0  R     yes
2808  pts/0  R     yes
3050  pts/1  Ss+   -bash
4049  pts/2  Ss+   -bash
4108  pts/2  R     yes
```

This demonstrated that the background CPU workloads continued running even though the client SSH connections that had been used to start them had disconnected.

### Engineering Lesson

The following are related but distinct:

```text
SSH client connection
        ↓
remote shell session
        ↓
processes started through that shell
```

A client connection disappearing does not necessarily prove that every process started during the session has also disappeared.

The timing of the SSH resets correlated with the CPU-pressure experiment, but this investigation did **not establish CPU pressure as the root cause** of the resets.

That investigation was therefore not allowed to derail the primary objective of the lab.

---

# Memory Investigation

## Establish a Memory Baseline

I inspected system memory using:

```bash
free -h
```

The baseline was approximately:

```text
total       1.9 GiB
used        230 MiB
free        550 MiB
buff/cache  1.1 GiB
available   1.5 GiB
```

The machine also reported:

```text
Swap: 0B
```

so no swap was configured during this experiment.

---

## Understand `free` vs `available`

A key distinction was:

```text
free
  ↓
completely unused RAM
```

versus:

```text
available
  ↓
Linux's estimate of memory that
could be supplied to applications
without requiring swapping
```

The `available` value is not an additional independent pool of memory that should simply be added to the other columns.

Linux can use otherwise-idle RAM for useful caching, and some cached/reclaimable memory can later be reclaimed when applications require RAM.

Therefore:

> Low `free` memory alone does not prove that a Linux machine is running out of usable RAM.

---

# Generate Controlled Memory Load

To create a safe memory workload on the approximately 2 GiB instance, I used a Python process that allocated roughly 300 MiB and held it temporarily:

```bash
python3 -c 'import time; x=bytearray(300*1024*1024); time.sleep(300)' &
```

The process received:

```text
PID 7347
```

This command was used as an experimental tool rather than syntax that needs to be memorised.

---

## Observe System-Wide Memory Changes

While the process was holding the allocation:

```bash
free -h
```

showed:

```text
              total   used    free    shared   buff/cache   available
Mem:          1.9Gi   515Mi   229Mi   2.0Mi    1.1Gi        1.2Gi
Swap:         0B      0B      0B
```

Compared with the baseline:

```text
used
230 MiB → 515 MiB
         ↑

free
550 MiB → 229 MiB
         ↓

available
1.5 GiB → 1.2 GiB
         ↓

buff/cache
~1.1 GiB → ~1.1 GiB
           approximately unchanged
```

This matched the prediction that allocating process memory would increase used memory and reduce the amount of memory available for additional workloads.

It also demonstrated that allocating 300 MiB to a process did not simply cause `buff/cache` to increase by 300 MiB.

---

# Connect Memory Usage to a Process

System-wide memory measurements showed that memory consumption had changed, but I also wanted process-level evidence.

I inspected PID `7347`:

```bash
ps -p 7347 -o pid,%cpu,%mem,rss,command
```

Observed:

```text
PID   %CPU  %MEM  RSS     COMMAND
7347  0.1   16.1  315868  python3 ...
```

The process consumed:

```text
%MEM = 16.1
```

while using only:

```text
%CPU = 0.1
```

This demonstrated that CPU consumption and memory consumption are separate resource dimensions.

A process can hold substantial memory while performing very little CPU work.

---

## Resident Set Size

`RSS` stands for:

> **Resident Set Size**

It provides an approximation of how much of a process's memory is currently resident in physical RAM.

The observed value:

```text
RSS = 315868 KiB
```

was approximately:

```text
308 MiB
```

This was consistent with the deliberately requested allocation of approximately 300 MiB plus additional memory required by the Python process itself.

The evidence connected:

```text
Python process
        ↓
~300 MiB allocation
        ↓
RSS ≈ 308 MiB
        ↓
%MEM ≈ 16%
        ↓
system available memory decreases
```

---

# Memory Recovery and Validation

The Python process had been configured to sleep for 300 seconds.

When I later attempted:

```bash
kill 7347
```

the shell reported:

```text
kill: (7347) - No such process
```

followed by:

```text
[1]+ Done python3 -c ...
```

This showed that the process had already completed naturally before the `kill` command was issued.

I independently verified the process state:

```bash
ps -p 7347
```

which returned only the headings and no process row.

PID `7347` therefore no longer existed.

---

## Prove Memory Recovery

Before the process ended:

```text
used       518 MiB
free       307 MiB
available  1.2 GiB
```

After the process ended:

```text
used       233 MiB
free       592 MiB
available  1.5 GiB
```

The transition was approximately:

```text
Process exists
        ↓
RSS ≈ 308 MiB
        ↓
available RAM ≈ 1.2 GiB
        ↓
process exits
        ↓
PID disappears
        ↓
used RAM ↓ ~285 MiB
        ↓
available RAM returns to ~1.5 GiB
```

This independently connected process lifetime to physical-memory consumption and recovery.

---

# CPU and Memory Mental Model

The complete lab connected two different types of resource pressure.

## CPU

```text
CPU-bound workload
        ↓
process becomes/remains runnable
        ↓
scheduler provides CPU time
        ↓
CPU utilisation increases
        ↓
runnable demand exceeds CPU capacity
        ↓
some runnable work waits for CPU
        ↓
load average reflects increased demand
```

## Memory

```text
Process allocates memory
        ↓
process resident memory increases
        ↓
RSS / %MEM increase
        ↓
system used memory increases
        ↓
available memory decreases
        ↓
process exits
        ↓
process-owned memory becomes reusable
        ↓
available memory increases
```

---

# Engineering Lessons Learned

## 1. CPU Utilisation and Load Average Are Different Measurements

A process reporting approximately 100% CPU can represent roughly one logical CPU's worth of CPU time.

Load average is not another way of expressing CPU percentage.

For the controlled CPU-bound workload in this lab, load average helped expose the amount of runnable demand relative to available CPU execution capacity.

---

## 2. Runnable Does Not Mean Executing

With:

```text
2 logical CPUs
3 runnable CPU-bound processes
```

only two of those single-threaded processes could execute on CPU at an instant.

The remaining runnable work could wait for CPU time while the scheduler distributed execution time among the processes.

This is how a machine with two logical CPUs could have a load average approaching three during the controlled experiment.

---

## 3. Longer Load Averages Retain More Historical Influence

When CPU demand increased suddenly:

```text
1-minute load → reacted fastest
5-minute load → reacted more slowly
15-minute load → reacted more slowly still
```

The longer-term values retained greater influence from the earlier, lower-load state.

They do not naturally decrease simply because time passes.

---

## 4. Low `free` RAM Does Not Automatically Mean Memory Pressure

Linux can use otherwise-idle RAM for useful caches.

Therefore:

```text
free
```

and:

```text
available
```

answer different questions.

For operational reasoning, `available` provided a more useful estimate of how much memory could be supplied to applications without swapping than `free` alone.

---

## 5. CPU and Memory Are Independent Resource Dimensions

The CPU workload showed approximately:

```text
~100% CPU
~0% memory
```

while the controlled memory workload showed:

```text
~0.1% CPU
~16% memory
```

A server being "slow" or "using lots of resources" is therefore not a sufficient diagnosis.

The engineer must identify **which resource is actually pressured**.

---

## 6. RSS Connects Process Memory to Physical RAM

`RSS` provided process-level evidence of memory currently resident in physical RAM.

This allowed the investigation to connect:

```text
system-wide memory change
        ↕
specific process memory consumption
```

rather than relying only on the machine-wide `free -h` output.

---

## 7. Recovery Should Be Proven

The experiment did not stop after generating resource pressure.

CPU workload was reduced and the load average was observed moving downward.

The memory-consuming process exited and both its PID disappearance and system memory recovery were independently verified.

This followed the same evidence-first principle as earlier labs:

```text
Baseline
   ↓
Prediction
   ↓
Controlled change
   ↓
Observation
   ↓
Interpretation
   ↓
Remove change
   ↓
Validate recovery
```

---

## 8. Correlation Is Not Root Cause

SSH resets occurred while the server was under sustained CPU pressure.

The timing made CPU pressure a reasonable hypothesis, but the evidence gathered did not establish it as the root cause.

The investigation therefore documented what was actually proven rather than turning correlation into a conclusion.

---

# Useful Command Reference

| Engineering Question                                                  | Command                                    |
| --------------------------------------------------------------------- | ------------------------------------------ |
| How long has the machine been running and what are its load averages? | `uptime`                                   |
| How many logical CPUs are available?                                  | `nproc`                                    |
| Create a controlled CPU-bound workload                                | `yes > /dev/null &`                        |
| Inspect the CPU and memory usage of `yes` processes                   | `ps -C yes -o pid,%cpu,%mem,command`       |
| How much system memory is used/free/available?                        | `free -h`                                  |
| Inspect CPU, memory and RSS for a known process                       | `ps -p <PID> -o pid,%cpu,%mem,rss,command` |
| Check whether a known PID still exists                                | `ps -p <PID>`                              |
| Inspect logged-in sessions                                            | `who`                                      |
| Inspect login sessions and their activity                             | `w`                                        |
| Inspect processes associated with specific terminals                  | `ps -t <TTYs> -o pid,tty,stat,cmd`         |
| Terminate a known process                                             | `kill <PID>`                               |

These commands are **reference material**, rather than syntax that all needs to be reproduced perfectly from memory.

The durable engineering skill is being able to ask:

> **Which resource appears pressured, what evidence supports that conclusion, which process is contributing to it, and how can I prove recovery after changing the workload?**

---

# Outcome

This lab demonstrated the ability to:

* Establish CPU and memory baselines before introducing a workload.
* Generate controlled CPU-bound processes.
* Inspect process-level CPU utilisation.
* Determine the number of logical CPUs available to a workload.
* Distinguish CPU utilisation from Linux load average.
* Observe CPU demand exceeding immediate execution capacity.
* Explain why runnable processes can wait for CPU time.
* Interpret 1-, 5-, and 15-minute load averages.
* Reduce CPU workload and observe recovery.
* Investigate unexpected SSH-session behaviour without prematurely assigning root cause.
* Interpret `free`, `available`, and `buff/cache` memory.
* Generate a controlled memory workload.
* Connect system-wide memory changes to a specific process.
* Interpret `%MEM` and RSS.
* Distinguish CPU-heavy from memory-heavy workloads.
* Verify that process memory becomes reusable after process termination.
* Diagnose resource pressure from operating-system evidence rather than assumptions.

The central operational lesson was:

> **"High resource usage" is not a diagnosis. Identify the constrained resource, connect system-wide measurements to the processes creating demand, and validate both the problem and the recovery with evidence.**

---

## Project Status

**Module 01 — Systems — Lab 5:Complete**
