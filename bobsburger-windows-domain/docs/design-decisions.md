## Domain Controller Network Requirements

### Requirement

The Windows client must be able to join and communicate with
the corp.bobsburger.com Active Directory domain.

- [Microsoft's Active Directory domain-join troubleshooting
documentation identifies several required network services
between a client computer and Domain Controller available to see under the sub header "Port Requirements" so I plan to use those only as opposed to the default allow-all outbound rule to follow least privilege](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/active-directory-domain-join-troubleshooting-guidance)
- The Windows client initiates the domain-related communication
toward the Domain Controller. Therefore, I will create Windows Client SG outbound rules and Domain Controller SG inbound rules. AWS Security Groups are stateful, so response traffic for
permitted connections does not require equivalent reverse rules.
- The Windows Client SG will permit the Active Directory-related (refer to the link above for the ports) traffic required to reach the Domain Controller Security Group. The Domain Controller Security Group will allow the corresponding inbound traffic from the Windows Client Security Group.
- Due to no business requirements explicitly stating a need for internet egress, I have decided to exclude implementing it for this Proof-of-Concept (POC)

The following network services and ports are required between the Windows client and Domain Controller to save you time as opposed to clicking on the link:

<img width="705" height="408" alt="Screenshot 2026-08-11 at 22 09 08" src="https://github.com/user-attachments/assets/b1079d15-a4db-4167-8b07-cf33d813c1a8" />

