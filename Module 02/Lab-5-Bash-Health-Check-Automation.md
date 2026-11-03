# Module 02 — Lab 5: Bash Health-Check Automation

## Business Problem

Bob’s Burger needed a repeatable way to check whether a web application was responding correctly without relying on engineers to manually inspect it.

An HTTP response alone was insufficient because the application could return HTTP `200 OK` while serving unexpected content.

The engineering team needed a lightweight health-check script that could verify application availability and expected response content, return meaningful exit codes, and maintain a timestamped history of results.

The solution also needed to handle common failures safely, including unavailable services, incorrect responses, and missing command-line dependencies.

## What I Built

- Launched a Python HTTP server on an Amazon Linux 2023 EC2 instance to simulate Bob’s Burger's application.

- Created a dedicated web directory containing an `index.html` file with the expected response `APPLICATION_OK`.

- Bound the HTTP server to `127.0.0.1:8080` so the test application was accessible locally rather than exposed through the instance's external network interfaces.

- Developed a Bash health-check script using `curl` and `grep` to verify HTTP availability and expected application content.

- Enabled `set -o pipefail` to ensure failures within the command pipeline could affect its exit status.

- Implemented distinct script exit codes for healthy, unhealthy, and missing-dependency conditions.

- Added timestamped logging using `tee -a` to display results and preserve previous log entries.

- Tested healthy and unhealthy conditions, including server unavailability, unexpected HTTP response content, and missing dependencies.

- Installed and validated ShellCheck to perform static analysis of the Bash script.

- Diagnosed an existing port conflict and corrected an unsafe web-server configuration that exposed the home directory.

## Health-Check Architecture

The solution used a local HTTP server, a Bash script, and a persistent log file.

```text
Amazon Linux 2023 EC2 Instance
│
├── Python HTTP Server
│   ├── 127.0.0.1:8080
│   └── Dedicated web directory
│       └── index.html
│           └── APPLICATION_OK
│
└── Bash Health-Check Script
    │
    ├── Check dependencies
    │   ├── curl
    │   └── grep
    │
    ├── Send HTTP request
    │   └── curl
    │
    ├── Verify expected content
    │   └── grep -Fxq
    │
    ├── Determine health status
    │   ├── Healthy → exit 0
    │   ├── Unhealthy → exit 1
    │   └── Missing dependency → exit 2
    │
    └── Record timestamped result
        └── tee -a
            ├── Terminal output
            └── health-check.log
```

### Application Health Verification

The script checked two conditions:

1. The HTTP request must succeed.
2. The response must contain the expected application health marker.

The central verification pipeline was:

```bash
curl --silent --show-error --fail --max-time 5 http://127.0.0.1:8080/ | grep -Fxq 'APPLICATION_OK'
```

The `curl` command sends the HTTP request, suppresses the progress meter, displays errors, treats HTTP error responses as failures, and limits the request to five seconds.

The `grep` command searches for the exact expected health marker:

- `-F` treats the marker as a fixed string.
- `-x` requires the entire line to match.
- `-q` suppresses normal output and communicates the result through its exit status.

This prevents a successful HTTP response containing unexpected content from automatically being treated as a healthy application.

The check verifies the defined HTTP and content conditions. It does not establish that every application dependency or business function is healthy.

### Pipeline Failure Handling

The script enabled:

```bash
set -o pipefail
```

Without `pipefail`, a pipeline normally returns the exit status of its final command.

With `pipefail`, the pipeline returns the exit status of the rightmost command that failed, or `0` if every command succeeded.

For example:

```text
curl exits 7
    │
    ▼
grep exits 1
    │
    ▼
pipefail
    │
    ▼
Pipeline exits 1
```

Because the pipeline returned a non-zero status, the `if` condition failed and the script executed its unhealthy branch.

The pipeline's exit status and the script's final exit code are separate concepts.

The pipeline determines which branch executes, while the explicit `exit` statement determines the script's final exit code.

### Exit Code Design

The health-check script used three exit codes:

| Exit code | Meaning | Condition |
|---|---|---|
| `0` | Healthy | HTTP request succeeds and expected content matches |
| `1` | Unhealthy | HTTP request fails or expected content is absent |
| `2` | Missing dependency | Required command is unavailable |

These exit codes were conventions defined for this script, rather than universal Bash exit-code meanings.

Using explicit exit codes makes the health-check result interpretable by other scripts and potential monitoring or automation systems.

## Bash Script Implementation

The script was stored at:

```text
~/lab5-healthcheck/health-check.sh
```

The implementation was:

```bash
#!/usr/bin/env bash

set -o pipefail

LOG_FILE="$HOME/lab5-healthcheck/health-check.log"

if ! command -v curl >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR: curl is missing" | tee -a "$LOG_FILE"
    exit 2
fi

if ! command -v grep >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR: grep is missing" | tee -a "$LOG_FILE"
    exit 2
fi

if curl --silent --show-error --fail --max-time 5 http://127.0.0.1:8080/ | grep -Fxq 'APPLICATION_OK'; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | Application healthy" | tee -a "$LOG_FILE"
    exit 0
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') | Application unhealthy" | tee -a "$LOG_FILE"
    exit 1
fi
```

### Dependency Validation

Before executing the HTTP health check, the script verified that `curl` and `grep` were available.

For example:

```bash
command -v curl >/dev/null 2>&1
```

`command -v` checks whether the shell can resolve the command.

The redirections suppress standard output and standard error because the script only needs the command's success or failure status.

If a required dependency is missing, the script logs the problem and exits with code `2`.

This distinguishes a health-check execution problem from an application health failure.

### Timestamped Logging

The script used:

```bash
echo "$(date '+%Y-%m-%d %H:%M:%S') | Application healthy" | tee -a "$LOG_FILE"
```

The logging process works as follows:

```text
echo
  │
  ▼
Timestamped status message
  │
  ▼
Pipe (|)
  │
  ▼
tee -a
  │
  ├── Display in terminal
  │
  └── Append to log file
      └── Preserve previous entries
```

`tee` writes the message to both standard output and the log file.

The `-a` option appends the new result rather than overwriting the file.

This provides a simple record of successive health-check results that can be inspected during troubleshooting.

## Troubleshooting & Recovery

### Incident 1 — HTTP Port Already in Use

**Symptom**

While starting the Python HTTP server, the requested port was already occupied.

**Investigation**

I investigated the existing process and listening socket rather than immediately terminating an unknown process.

The objective was to identify which process owned the port and determine whether the existing listener was expected.

**Root Cause**

Another process was already listening on the requested port, preventing a second server from binding to the same address and port combination.

**Engineering Lesson**

A port-binding failure should be investigated using process and socket evidence before taking corrective action.

Blindly terminating processes risks disrupting legitimate services.

### Incident 2 — Unsafe Web Directory Exposure

**Symptom**

The Python HTTP server was initially serving content from the home directory.

This exposed a directory listing containing files and directories that were not intended to be published, including `.ssh`.

**Root Cause**

The server's document root was too broad for the intended application test.

The Python HTTP server served content from its configured directory, which initially included unrelated user files.

**Recovery**

I created a dedicated web directory:

```text
~/lab5-healthcheck/www/
```

The directory contained an `index.html` file with the expected health marker:

```text
APPLICATION_OK
```

I configured the HTTP server to serve that dedicated directory and listen on:

```text
127.0.0.1:8080
```

This restricted the test application's served content and limited the listener to the local loopback interface.

**Validation**

The server returned the expected application content from the dedicated web directory.

The health-check script could successfully retrieve and verify the response.

**Engineering Lesson**

A working HTTP server is not necessarily configured safely.

The document root and listening interface should be deliberately selected to avoid exposing unnecessary files or network services.

## Testing & Validation

I tested the health-check script under several controlled conditions.

| Test scenario | Expected result | Script exit |
|---|---|---|
| Server running, correct content | Application healthy | `0` |
| Server stopped | Application unhealthy | `1` |
| HTTP `200 OK`, incorrect content | Application unhealthy | `1` |
| Required command unavailable | Dependency error | `2` |
| Server restored with correct content | Application healthy | `0` |

### Healthy Application

The Python HTTP server was running and returned:

```text
APPLICATION_OK
```

The health-check script identified the expected response and reported the application as healthy.

The script exited with code `0`.

### Server Unavailable

I stopped the HTTP server to simulate an unavailable application.

The HTTP request could no longer establish a successful connection.

The script reported the application as unhealthy and exited with code `1`.

### Unexpected Response Content

I tested a scenario where the HTTP server returned a successful response but the content did not match the expected health marker.

For example:

```text
MAINTENANCE_MODE
```

Although the HTTP request succeeded, the content check failed.

The script correctly classified the application as unhealthy.

This demonstrated that HTTP availability and application content verification are distinct checks.

### Missing Dependencies

I simulated conditions where required commands could not be resolved.

The dependency checks identified the missing command, recorded an error message, and exited with code `2`.

This confirmed that missing prerequisites were handled separately from application failures.

### Recovery Validation

After the failure tests, I restored the expected application response and reran the health check.

The script returned to the healthy state, confirming that the implementation could detect both failures and recovery.

## Static Analysis & Script Validation

I installed ShellCheck v0.11.0 to inspect the Bash script for potential shell scripting issues.

Before using the downloaded release, I compared the archive's calculated SHA-256 checksum with the expected checksum published by the official release source.

This provided an integrity check against the trusted reference before installation.

I then validated the script using three complementary approaches:

| Validation method | Purpose |
|---|---|
| `bash -n health-check.sh` | Check Bash syntax without executing the script |
| `shellcheck health-check.sh` | Perform static analysis for common shell scripting problems |
| `bash health-check.sh` | Execute the script and test its actual behaviour |

The installed ShellCheck binary reported no warnings for the script.

These validation methods address different risks.

```text
Syntax checking
    │
    ▼
Is the Bash syntax valid?
    │
    ▼
Static analysis
    │
    ▼
Are common scripting issues detected?
    │
    ▼
Runtime testing
    │
    ▼
Does the script behave correctly
under realistic conditions?
```

Passing syntax checking or static analysis does not guarantee correct runtime behaviour.

The controlled healthy and failure tests were therefore necessary to validate the script's actual behaviour.

## Lessons Learned

- Bash scripts can turn repetitive operational checks into repeatable procedures with consistent outputs and exit codes.

- HTTP `200 OK` indicates that the request succeeded, but does not prove that the response contains the expected application content.

- Combining `curl` and `grep` allows a health check to verify both HTTP availability and a defined response marker.

- `set -o pipefail` changes pipeline exit-status behaviour so failures are not necessarily hidden by a successful final command.

- A pipeline's exit status is distinct from a script's final exit code. Conditional logic and explicit `exit` statements determine how pipeline results are translated into script outcomes.

- Explicit exit-code conventions allow different failure categories to be distinguished by other programs or automation.

- Dependency checks prevent missing command-line tools from being silently misclassified as application health failures.

- `tee -a` displays results while appending them to a log file, preserving previous entries for later investigation.

- A dedicated web document root and loopback binding reduce unnecessary exposure when running a local test service.

- Port conflicts should be investigated using process and socket evidence rather than immediately terminating processes.

- SHA-256 checksum comparison provides evidence that a downloaded file matches a trusted reference, but does not independently establish that the software is safe.

- Bash syntax checking, ShellCheck static analysis, and runtime testing provide complementary forms of validation.

- A reliable health check must be tested against both successful and unsuccessful conditions, including recovery after failure.

## Project Status

**Implementation and validation complete** — the Bash health-check script, dependency handling, exit-code behaviour, timestamped logging, controlled failure testing, recovery validation, and static analysis were demonstrated successfully.
