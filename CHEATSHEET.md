# Cloud Engineering Command Cheat Sheet

> Quick-reference commands encountered during labs and projects.
> These are reference material — not commands that must all be memorised.

## Module 01 — Systems

### Processes

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find a process when I know part of its command/name | `ps aux \| grep http.server` | Searches the broad process listing for matching command text |
| Inspect a known process | `ps -p <PID> -o pid,%cpu,%mem,command` | PID, CPU, memory and command |
| Check whether a known PID still exists | `ps -p <PID>` | Whether that process is still present |

### Networking

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find what is associated with port 8080 | `lsof -i :8080` | Network resources/processes associated with port 8080 |

### Filesystem / Executables

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| See what path the shell resolves for Python | `which python3` | Command resolution through the current `PATH` |
| Inspect a filesystem entry | `ls -l <path>` | File type, permissions, ownership, symlink target, etc. |

---

## Module 02 — Linux
<!-- Add commands naturally as they are encountered -->

## Module XX — Troubleshooting Toolkit
<!-- Add this later once commands have appeared naturally across the curriculum -->
