# Module 01 — Lab 5: Linux CPU & Memory Resource Investigation

## Business Problem

Bob’s Burger needed a Linux server where engineers could identify resource-heavy processes, distinguish CPU consumption from memory consumption, and investigate potential performance problems using system evidence.

Engineers needed to establish normal resource usage, introduce controlled workloads, identify the responsible processes, and verify that the system recovered after those workloads ended.

## What I Built

- Used a Linux EC2 instance with **2 logical CPUs** and approximately **1.9 GiB of RAM** as the investigation environment.
- Established baseline CPU, memory, and process measurements using `top`.
- Generated a controlled CPU-intensive workload using `yes`, automatically terminated after 15 seconds.
- Identified the CPU-intensive process through its PID, command, and `%CPU`.
- Verified that system-wide CPU utilisation returned to baseline after the workload ended.
- Generated a controlled Python workload that allocated approximately 200 MiB of memory for 15 seconds.
- Investigated resident memory, virtual memory, process state, and system-wide available memory.
- Verified that memory availability recovered after the Python process exited.

## Resource Investigation Design

The investigation followed a controlled workflow:

```text
Linux EC2 Instance
│
├── Baseline Monitoring
│   └── top
│       ├── CPU utilisation
│       ├── Memory availability
│       └── Process activity
│
├── Controlled CPU Workload
│   └── yes > /dev/null
│       └── timeout 15s
│
├── Controlled Memory Workload
│   └── Python bytearray (200 MiB)
│       └── sleep 15s
│
└── Recovery Validation
    ├── Workload process exits
    ├── CPU returns to baseline
    └── Available memory recovers
```

### Establishing the Baseline

I used:

```bash
top
```

to inspect normal resource usage before introducing any workload.

The initial measurements showed:

```text
Logical CPUs:       2
CPU idle:           99.8%
Total RAM:          1909.6 MiB
Available RAM:      1639.0 MiB
Swap:               0 MiB
```

The server was almost entirely CPU-idle and had substantial available memory.

Establishing a baseline provided a reference for determining whether later resource consumption was abnormal and whether the system recovered after the experiment.

### CPU Capacity vs CPU Utilisation

I used:

```bash
nproc
```

The output was:

```text
2
```

This showed that the calling process had access to two logical CPUs.

`nproc` reports available processing units, not how many CPUs are currently idle.

A logical CPU can already be executing work while remaining part of the processing capacity available to the operating system's scheduler.

## CPU Investigation

### Controlled Workload

I generated CPU activity using:

```bash
timeout 15s yes > /dev/null
```

The `yes` process continuously generated output, while `/dev/null` discarded that output.

The `timeout` command limited the workload to approximately 15 seconds, preventing it from running indefinitely.

### Evidence

During the workload, `top` showed:

```text
PID      COMMAND   %CPU
33218    yes       99.3
```

System-wide CPU measurements showed:

```text
%Cpu(s): 30.7 us, 19.1 sy, 49.8 id
```

The `yes` process was consuming approximately 100% of one logical CPU.

Because the instance had two logical CPUs, occupying approximately one CPU reduced system-wide idle capacity to around 50%.

The measurements were consistent with the prediction made before executing the workload.

### CPU Recovery

After the 15-second workload ended, I ran `top` again.

The results showed:

```text
%Cpu(s): 100.0 id
```

The `yes` process was no longer present in the observed process list, and system-wide CPU utilisation returned close to its original baseline.

Small fluctuations between approximately 100% and the high 90s were expected because background processes and operating system activities periodically require CPU time.

## Memory Investigation

### Controlled Workload

I used Python to allocate and retain approximately 200 MiB of memory:

```bash
python3 -c 'import time; data = bytearray(200 * 1024 * 1024); print("Holding 200 MiB for 15 seconds", flush=True); time.sleep(15)'
```

The `bytearray` allocated memory, while `time.sleep(15)` kept the process alive without requiring sustained CPU execution.

The allocation was deliberately limited because the EC2 instance had approximately 1.6 GiB of available RAM and no swap configured.

### Evidence

During the workload, `top` showed:

```text
PID      COMMAND    S   %CPU   %MEM   VIRT     RES
33522    python3    S    4.0   10.9   434292   213580
```

The `VIRT` and `RES` values were reported in KiB.

This represented approximately:

- **424 MiB VIRT** — virtual address space associated with the Python process.
- **209 MiB RES** — process memory resident in physical RAM.
- **10.9% MEM** — approximately 10.9% of the system's physical RAM.

The process showed state `S`, indicating interruptible sleep.

Although the process was sleeping and consuming little CPU time, its allocated memory remained resident in RAM.

This demonstrated that a process can retain physical memory without continuously executing CPU instructions.

### Virtual vs Resident Memory

The investigation reinforced the distinction between two process-level measurements:

```text
Process Virtual Address Space (VIRT)
│
├── Memory resident in physical RAM (RES)
│
└── Other virtual memory regions
    └── Not necessarily resident in RAM
```

`VIRT` represents the virtual address space associated with a process, including mapped regions that may not currently occupy physical RAM.

`RES` represents the portion currently resident in physical RAM, including resident pages that may be shared with other processes.

A large `VIRT` value therefore does not necessarily indicate an equivalent amount of physical RAM consumption.

### System Memory Evidence

During the Python workload:

```text
Total RAM:          1909.6 MiB
Free RAM:           1329.9 MiB
Available RAM:      1421.4 MiB
Used RAM:            353.0 MiB
```

The `avail Mem` measurement estimates how much memory can be made available to new applications without swapping, including reclaimable memory.

It is generally more useful than the `free` measurement when investigating overall memory pressure.

### Memory Recovery

After the Python process exited, I inspected the system again.

The measurements showed:

```text
Total RAM:          1909.6 MiB
Free RAM:           1525.7 MiB
Available RAM:      1617.2 MiB
Used RAM:            157.2 MiB
```

Available memory increased from **1421.4 MiB to 1617.2 MiB**, recovering by approximately 196 MiB.

The Python process was no longer present in the observed process list.

This demonstrated that the temporary memory allocation had been released and that system memory availability had returned close to its original baseline.

## Troubleshooting & Recovery

### Investigation Approach

The experiments established a repeatable method for diagnosing resource-related performance problems:

```text
Performance Problem
        │
        ▼
Establish / Compare Baseline
        │
        ▼
Inspect System CPU & Memory
        │
        ▼
Identify Resource-Heavy Process
        │
        ▼
Investigate Process Metrics
        │
        ▼
Remove Controlled Workload
        │
        ▼
Verify Resource Recovery
```

### Process Identification

I used `top` to examine:

- `PID` — process identifier.
- `COMMAND` — process name.
- `%CPU` — CPU consumption.
- `%MEM` — percentage of physical RAM represented by resident memory.
- `VIRT` — virtual address space.
- `RES` — resident memory.
- `S` — process state.

A process disappearing from the visible `top` list does not necessarily prove it has exited, because the default display sorts processes by CPU usage.

A specific PID can be inspected using:

```bash
ps -p <PID> -o pid,stat,%cpu,%mem,rss,comm
```

This helps determine whether the process still exists and inspect its state and resource consumption.

### Recovery Validation

Recovery should be demonstrated using system evidence rather than assuming that terminating a process has resolved the problem.

For CPU pressure, I compared system-wide idle CPU before, during, and after the workload.

For memory pressure, I compared available memory before, during, and after the workload.

The controlled experiments demonstrated that both CPU and memory utilisation returned close to their original baselines after the responsible processes exited.

## Lessons Learned

- CPU capacity and CPU utilisation are different measurements. `nproc` reports logical CPUs available to the calling process, not how many are idle.
- A process consuming approximately 100% CPU may occupy only one logical CPU. On a two-logical-CPU system, this can correspond to approximately 50% overall CPU utilisation.
- Linux processes can remain alive and retain runtime state without continuously consuming CPU time.
- A sleeping process can retain substantial physical memory while waiting for an event.
- `VIRT` represents a process's virtual address space, whereas `RES` represents memory currently resident in physical RAM.
- A process's virtual address space does not necessarily correspond to an equivalent amount of physical RAM consumption.
- `avail Mem` provides a more useful estimate of memory available to applications than looking at unused RAM alone.
- A PID identifies a process but does not reliably distinguish system processes from application processes based on its numerical value.
- Resource consumption should be compared against a baseline before concluding that a process is causing performance problems.
- Controlled experiments should use bounded workloads and verify that resource utilisation returns to normal afterward.
- Process disappearance alone is insufficient to prove full recovery; system-level metrics must also be checked.

## Project Status

**Complete** — baseline monitoring, controlled CPU load, controlled memory allocation, process identification, resource interpretation, and recovery validation were demonstrated successfully.
