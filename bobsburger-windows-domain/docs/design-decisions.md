## Domain Controller Network Requirements

### Requirement

The Windows client must be able to join and communicate with
the corp.bobsburger.com Active Directory domain.

- [Microsoft's Active Directory domain-join troubleshooting
documentation identifies several required network services
between a client computer and Domain Controller available to see under the sub header "Port Requirements" so I plan to use those](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/active-directory-domain-join-troubleshooting-guidance)
- The Windows client initiates the domain-related communication
toward the Domain Controller. Therefore, I will create a Windows Client SG outbound and Domain Controller SG inbound. AWS Security Groups are stateful, so response traffic for
permitted connections does not require equivalent reverse rules.
- Due to no business requirements expliciity stating a need for internet egress, I have decided to exclude implementing it for this Proof-of-Concept (POC)
