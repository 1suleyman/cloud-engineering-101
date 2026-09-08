# Cloud Engineering Command Cheat Sheet

> Quick-reference commands encountered during labs and projects.
> These are reference material — not commands that must all be memorised.

## Module 01 — Systems

### Processes

| What am I trying to find out? | Command | What it tells me |
|---|---|---|
| Find a process when I know part of its command/name | `ps aux \\| grep http.server` | Searches the broad process listing for matching command text |
| Inspect a known process | `ps -p <PID> -o pid,%cpu,%mem,command` | PID, CPU, memory and command |
| Check whether a known PID still exists | `ps -p <PID>` | Whether that process is still present |

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

---

## Module 02 — Linux
<!-- Commands will be added naturally as they are encountered -->

## Module XX — Troubleshooting Toolkit
<!-- Commands will be added naturally as they are encountered  -->
