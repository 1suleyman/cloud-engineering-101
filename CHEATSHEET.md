# Cloud Engineering Command Cheat Sheet

> Quick-reference commands encountered during labs and projects.
> These are reference material — not commands that must all be memorised.

## Module 01 — Systems

### Processes

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find a process when I know part of its command/name | `ps aux \| grep http.server` | Searches the broad process listing for matching command text |
| Inspect a known process | `ps -p <PID> -o pid,%cpu,%mem,command` | PID, CPU, memory and command |
| How much physical RAM is a known process currently using? | `ps -p <PID> -o pid,%cpu,%mem,rss,command` | Shows CPU usage, memory percentage, RSS (resident memory), and command for a specific process |
| Check whether a known PID still exists | `ps -p <PID>` | Whether that process is still present |

### CPU / Memory

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| How many logical CPUs are available to this workload? | `nproc` | Reports the number of processing units available to the current process |
| How much RAM is used, free, and available? | `free -h` | Shows human-readable system memory usage, including used, free, cache, available memory, and swap |

### Ports / Network Resources

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find what is associated with port 8080 | `lsof -i :8080` | Network resources/processes associated with port 8080 |

### Filesystem / Executables

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| See what path the shell resolves for Python | `which python3` | Command resolution through the current `PATH` |
| See what path the shell resolves for a specific executable | `which python3.13` | The executable path resolved through the current `PATH` |
| Inspect a filesystem entry | `ls -l <path>` | File type, permissions, ownership, size, modification time and symlink target |

### Service Testing

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Start a tiny local HTTP service | `python3 -m http.server 8080` | Runs Python's built-in HTTP server on port 8080 |
| Test whether the local HTTP service responds | `curl http://localhost:8080` | Sends an HTTP request to the local service and displays its response |

### Boot / System State

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| How long has this Linux system been running since its most recent boot? | `uptime` | Current time, time since the latest boot, logged-in sessions, and 1/5/15-minute load averages |
| What process is running as PID 1? | `ps -p 1` | Identifies the PID 1 process; on our Amazon Linux system this was `systemd` |
| What uniquely identifies the current Linux boot? | `cat /proc/sys/kernel/random/boot_id` | Displays the current boot's unique boot ID |

### systemd / Services

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| What is the current state of a specific service? | `systemctl status <service>` | Shows the unit's loaded/active state, main process, recent logs, and other runtime information |
| Which service units are currently running? | `systemctl --type=service --state=running` | Lists service units currently in the running state |

---

## Module 02 — Linux

<!-- Commands will be added naturally as they are encountered -->

## Module XX — Troubleshooting Toolkit

<!-- Commands will be added naturally as they are encountered -->
