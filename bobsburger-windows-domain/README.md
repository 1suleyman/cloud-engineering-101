# Bob's Burger Windows Domain Infrastructure

## Business Problem

Bob's Burger Corporation is expanding its head office.

Employee accounts are currently managed locally on individual
Windows computers. As the company grows, managing separate local
accounts across multiple machines is becoming difficult to scale
and administer.

The IT team requires a proof-of-concept Windows domain environment
that demonstrates how employee identities and authentication can
be centrally managed.

## Project Goal

Design and deploy a Windows domain environment in AWS that allows
Bob's Burger Corporation to centrally manage employee identities
and allows domain users to authenticate from a domain-joined
Windows client.

## Business Requirements

- Host the environment in AWS.
- Create the `corp.bobsburger.com` Windows domain.
- Centrally manage employee identities.
- Create at least three fictional employee accounts.
- Create at least two security groups representing business access requirements.
- Deploy a separate Windows client.
- Join the Windows client to `corp.bobsburger.com`.
- Successfully authenticate a domain employee from the client.
- Capture evidence proving the solution works.

## Architecture
coming...

## Design Decisions

### Domain Controller Network Requirements

#### Requirement

The Windows client must be able to join and communicate with
the corp.bobsburger.com Active Directory domain.

- [Microsoft's Active Directory domain-join troubleshooting
documentation identifies several required network services
between a client computer and Domain Controller available to see under the sub header "Port Requirements" so I plan to use those only as opposed to the default allow-all outbound rule to follow least privilege](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/active-directory-domain-join-troubleshooting-guidance).
- The Windows client initiates the domain-related communication
toward the Domain Controller. Therefore, I will create Windows Client SG outbound rules and Domain Controller SG inbound rules. AWS Security Groups are stateful, so response traffic for
permitted connections does not require equivalent reverse rules.
- The Windows Client SG will permit the Active Directory-related (refer to the link above for the ports) traffic required to reach the Domain Controller Security Group. The Domain Controller Security Group will allow the corresponding inbound traffic from the Windows Client Security Group.
- Due to no business requirements explicitly stating a need for internet egress, I have decided to exclude implementing it for this Proof-of-Concept (POC).

The following network services and ports are required between the Windows client and Domain Controller to save you time as opposed to clicking on the link:

<img width="705" height="408" alt="Screenshot 2026-08-11 at 22 09 08" src="https://github.com/user-attachments/assets/b1079d15-a4db-4167-8b07-cf33d813c1a8" />

Note: [Microsoft's current guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/default-dynamic-port-range-tcpip-chang) states that Windows Server 2008 and later use the default dynamic port range 49152–65535, replacing the lower dynamic ranges used by older Windows versions. As this POC uses a modern Windows Server version, the Security Group design will permit TCP 49152–65535 for dynamic RPC communication rather than the broader 1024–65535 range shown in the original domain-join port table. This reduces unnecessary network exposure while supporting the required Active Directory RPC communication.

### Private Administrative Access with AWS Systems Manager

#### Requirement

Both `DC01` and `CLIENT01` need to be administratively accessible without assigning public IP addresses or exposing inbound RDP access from the Internet.

### Design Decision

AWS Systems Manager Fleet Manager will be used for administrative access to both Windows EC2 instances.

The instances will remain private and will communicate with Systems Manager through interface VPC endpoints in `eu-west-2`.

### Security Group Design

A shared `SSM-ManagedNode-SG` will be attached to both `DC01` and `CLIENT01`.

Its purpose is to allow the managed Windows instances to initiate the required HTTPS communication toward the Systems Manager interface endpoints.

```text
DC01
├── DC-SG
└── SSM-ManagedNode-SG
          │
          │ HTTPS TCP 443
          ▼
    SSM-Endpoint-SG
          │
          ▼
SSM Interface Endpoints
├── ssm
└── ssmmessages


CLIENT01
├── Client-SG
└── SSM-ManagedNode-SG
          │
          │ HTTPS TCP 443
          ▼
    SSM-Endpoint-SG
          │
          ▼
SSM Interface Endpoints
├── ssm
└── ssmmessages
```

The following Systems Manager interface endpoints will be used:

- `com.amazonaws.eu-west-2.ssm`
- `com.amazonaws.eu-west-2.ssmmessages`

`ec2messages` has intentionally not been included. Although `eu-west-2`
supports the `ec2messages` endpoint, current Systems Manager Agent
communication uses `ssmmessages`, which AWS recommends over
`ec2messages`.

<img width="601" height="253" alt="Screenshot 2026-08-16 at 16 12 18" src="https://github.com/user-attachments/assets/204c9b77-0f38-4b75-a3da-26a80ec7133f" />

[Reference if you want to research for yourself](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-release-history.html)

The Security Group responsibilities are:

* `DC-SG` — Active Directory-specific network rules for the Domain Controller.
* `Client-SG` — Active Directory-specific network rules for the domain-joined Windows client.
* `SSM-ManagedNode-SG` — reusable outbound HTTPS access from managed EC2 instances to the SSM interface endpoints.
* `SSM-Endpoint-SG` — inbound HTTPS access to the interface endpoints from `SSM-ManagedNode-SG`.

This allows the SSM networking rules to be reused across both Windows instances while keeping the Domain Controller and client-specific rules separate.

Because AWS Security Group permissions are additive, broader outbound rules such as `Allow All` should not also be attached if the intention is to maintain restricted egress.

### Why This Approach

This avoids:

* assigning public IP addresses to the Windows instances,
* exposing inbound RDP port `3389`,
* deploying an additional bastion EC2 instance,
* adding a full Client VPN purely for this POC,
* providing general Internet egress.

It also keeps the project focused on the Windows domain infrastructure while still providing a controlled AWS-native administrative access path.


## Build / Implementation
coming...

## Troubleshooting

### SSM Interface Endpoint – Private DNS Failure

When attempting to create the SSM interface VPC endpoint with Private DNS
enabled, AWS returned:

<img width="796" height="56" alt="Screenshot 2026-08-19 at 18 35 40" src="https://github.com/user-attachments/assets/3ffa05b5-6fcd-4886-81aa-c6b272f06c09" />

**Resolution**

Enabled the required DNS settings on `bobs-burgers-dev-vpc` and retried the
SSM interface endpoint creation.

DNS hostnames (enableDnsHostnames) — for a nondefault VPC, this is normally disabled by default. It controls whether instances receive Amazon-provided DNS hostnames.

<img width="273" height="115" alt="Screenshot 2026-08-19 at 18 38 39" src="https://github.com/user-attachments/assets/a77c41f6-d4b5-4490-bd3f-2087f245a4e1" />


## Validation / Evidence
coming...

## Production Considerations

### Domain Controller Internet Connectivity

- A production Domain controller should not be public exposed to the internet but controlled internet outbound connectivity could prove useful for operational dependencies such as patching etc this could be done with a NAT Gateway


## Outcome / Lessons Learned
[Complete when the project is finished]

## Project Status

🚧 In Progress
