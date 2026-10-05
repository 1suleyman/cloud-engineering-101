# Module 02 — Lab 1: Linux User, Group & Permission Management 

## Business Problem

Bob’s Burger needed a Linux server where human users could collaborate through controlled group permissions, while applications could run under dedicated non-human service accounts.

Access needed to follow the principle of least privilege while allowing administrators to diagnose and safely recover from permission failures.

## What I Built

- Created human user accounts and an `engineers` group to manage shared access through group membership rather than individual user permissions.
- Configured `/srv/bobs-burgers` as a protected shared workspace for authorized engineers.
- Used an unrelated user, `joe`, to validate that unauthorized users could not access protected content.
- Configured **setgid** so newly created content inherits the `engineers` group ownership.
- Configured a **default ACL** to provide appropriate inherited access to newly created content.
- Created the non-human `bobs-app` service account for running application processes.
- Introduced a controlled permission failure, diagnosed it using system evidence, applied a least-privilege fix, and validated recovery.

## Access Design

The shared workspace was configured around group-based access:

```text
Linux Server
│
├── Human Users
│   ├── ec2-user ──┐
│   └── bob ───────┼──> engineers
│                  │        │
│                  │        ▼
│                  │   /srv/bobs-burgers
│                  │
│   joe ───────────┘
│   unauthorized
│
└── Service Identity
    └── bobs-app
        └── non-interactive application account
```

### Group-Based Access

I used an `engineers` group instead of managing permissions separately for every engineer.

This makes access management scalable: engineers can be added to or removed from the group while the permissions on the shared resources remain consistent.

### Setgid Inheritance

The shared directory used the setgid bit:

```text
drwxrws--- root engineers /srv/bobs-burgers
```

This ensures that newly created content inherits the `engineers` group rather than normally taking the creator process's effective group.

This preserves the shared ownership model regardless of which engineer creates the content.

### Default ACL

A default ACL was configured on the shared directory so access rules could be inherited by newly created content.

For example:

```bash
sudo setfacl -d -m g:engineers:rwx /srv/bobs-burgers
```

Setgid and the default ACL solve different problems:

```text
setgid
   ↓
inherited group ownership

default ACL
   ↓
inherited access rules
```

Effective ACL permissions can still be constrained by the permissions requested when an object is created and its resulting ACL mask.

## Service Account Design

I created `bobs-app` as a dedicated non-human identity:

```bash
sudo useradd -r -s /sbin/nologin bobs-app
```

Using a dedicated service account means application processes do not need to run as `root` or under a human engineer's identity.

This provides clearer separation between human and application access, supports least privilege, and reduces the potential blast radius if an application is compromised.

`/sbin/nologin` prevents normal interactive login but does not prevent processes from running under the `bobs-app` identity.

## Troubleshooting & Recovery

### Symptom

Bob was a member of `engineers` but received `Permission denied` when attempting to create a file inside:

```text
/srv/bobs-burgers
```

### Evidence

Rather than immediately changing permissions, I checked:

```bash
id bob
ls -ld /srv/bobs-burgers
```

Bob's identity confirmed membership of `engineers`, while the directory showed:

```text
drwxr-s---+ root engineers
```

The group had lost its **write (`w`) permission**.

### Root Cause

The shared directory's group permissions had been misconfigured.

Because creating a file requires write permission on the containing directory, members of `engineers` could no longer create new directory entries.

### Recovery

I restored only the missing permission:

```bash
sudo chmod g+w /srv/bobs-burgers
```

I deliberately avoided a broad fix such as:

```text
chmod 777
```

because that would grant unnecessary access to all users rather than correcting the specific permission failure.

### Validation

I tested the repaired configuration as Bob:

```bash
sudo -u bob touch /srv/bobs-burgers/incident-test.txt
```

The operation succeeded.

The directory permissions were then rechecked and showed:

```text
drwxrws---+ root engineers
```

This demonstrated that:

- group write access had been restored;
- setgid remained enabled;
- the existing ACL remained present;
- Bob could again create content.

Earlier negative testing with `joe`, who was not a member of `engineers`, also produced `Permission denied`, demonstrating that the access boundary excluded an unintended user.

## Lessons Learned

- Linux users operate within the same filesystem hierarchy, while identity, group membership, permissions, and other access controls determine which resources they can access.
- Group-based permissions provide a scalable way to manage team access instead of assigning permissions individually to every engineer.
- Directory setgid preserves shared group ownership by making newly created content inherit the parent directory's group.
- Default ACLs provide inherited access rules, while the ACL mask constrains the effective permissions available to relevant ACL entries.
- A service account provides a dedicated identity for applications without requiring an interactive human login.
- Permission failures should be diagnosed from evidence—including identity, group membership, ownership, permissions, and ACLs—before configuration is changed.
- Least-privilege recovery means correcting the specific faulty permission rather than applying unnecessarily broad access.

## Project Status

**Complete** — shared access, unauthorized-user isolation, service identity, inheritance behavior, controlled failure, recovery, and validation were demonstrated successfully.

