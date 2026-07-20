# Lesson 3 – Hostnames, Domains & Fully Qualified Domain Names (FQDN)

## Learning Objective

Understand how devices are named on a network and how Fully Qualified Domain Names (FQDNs) uniquely identify devices within an organisation.

---

## Notes

### What is a Hostname?

A hostname is a name assigned to a device on a network.

Examples:

- printer
- db-server
- web01
- manager-laptop

---

### What is a Domain?

A domain is a unique name used to organise and identify devices belonging to an organisation or environment.

Example:

- bobsburger.com

---

### What is an FQDN?

An FQDN (Fully Qualified Domain Name) is the complete name of a device.

Example:

```
printer.dev.bobsburger.com
```

Breakdown:

| Component | Value |
|-----------|-------|
| Hostname | printer |
| Subdomain | dev |
| Domain | bobsburger |
| Top-Level Domain (TLD) | .com |

---

## Why Do We Use Domains?

Without domains, many organisations could have devices with identical hostnames.

Example:

```
printer.dev.bobsburger.com
printer.dev.alicesbakery.com
```

Both devices are named **printer**, but their FQDNs uniquely identify them.

---

## Key Takeaways

- Every device can have a hostname.
- Domains organise devices into logical groups.
- An FQDN uniquely identifies a device.
- Humans use names; networking ultimately uses IP addresses.
