## Domain Controller Network Requirements

### Requirement

The Windows client must be able to join and communicate with
the corp.bobsburger.com Active Directory domain.

### Research

[Microsoft's Active Directory domain-join troubleshooting
documentation identifies several required network services
between a client computer and Domain Controller](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/active-directory-domain-join-troubleshooting-guidance)

<img width="753" height="554" alt="Screenshot 2026-08-06 at 21 41 23" src="https://github.com/user-attachments/assets/0827a9a3-ebe0-4d25-91c8-4ff32d9edcbc" />


| Protocol | Port | Purpose |
|---|---|---|
| DNS | 53 TCP/UDP | DNS/domain service discovery |
| DC Locator | 389 UDP | Domain Controller discovery |
| LDAP | 389 TCP | Directory communication |
| Kerberos | 88 TCP | Authentication |
| RPC | 135 TCP | RPC endpoint mapping |
| SMB | 445 TCP | Windows/AD shared resources |
| RPC | 1024-65535 TCP | Dynamic RPC communication |

### Traffic Direction

The Windows client initiates the domain-related communication
toward the Domain Controller.

Therefore:

Windows Client SG outbound <-> Domain Controller SG inbound

AWS Security Groups are stateful, so response traffic for
permitted connections does not require equivalent reverse rules.
