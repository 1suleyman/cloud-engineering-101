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

### Private Access to Amazon S3

The Windows instances intentionally do not have public IP addresses or
general Internet egress.

During implementation, a requirement arose to retrieve software required
for Systems Manager administrative functionality. Rather than introducing
general Internet access through a NAT Gateway, I plan to provide private
access to Amazon S3 using an S3 Gateway VPC endpoint.

The intended remediation path is:

```text
Internet-connected workstation
        │
        │ Download required package
        ▼
Private S3 bucket
        │
        │ S3 Gateway VPC Endpoint
        ▼
Private VPC
        │
        ▼
DC01
```

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

### Fleet Manager PowerShell Keyboard Input Failure

After successfully registering `DC01` as a Systems Manager managed node,
I connected to the instance using AWS Systems Manager Fleet Manager.

The graphical remote desktop connection succeeded, but keyboard input
inside Windows PowerShell did not function correctly.

#### Symptom

PowerShell opened successfully, but normal keyboard input could not be
entered at the command prompt.

<img width="866" height="717" alt="image" src="https://github.com/user-attachments/assets/f4ed933a-6f4f-4417-93fd-836bd051c9ad" />

#### Investigation

[AWS documentation states that Windows Server 2022 managed nodes require
PSReadLine version `2.2.2` or later for PowerShell keyboard functionality
when using Fleet Manager.](https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-remote-desktop-connections.html)

<img width="1460" height="900" alt="image" src="https://github.com/user-attachments/assets/ed015647-72f7-440a-8519-3f4a7c3c7dd1" />


To determine whether this requirement was satisfied, I used Systems Manager
Run Command with the `AWS-RunPowerShellScript` document to query the
installed PSReadLine version.

```powershell
Get-Module -ListAvailable PSReadLine |
    Select-Object Name, Version, Path
```

The command completed successfully and returned:

<img width="1051" height="591" alt="Screenshot 2026-08-20 at 16 38 44" src="https://github.com/user-attachments/assets/79b55f8c-19e8-4f5f-acff-61efa511f993" />

The installed version (`2.0.0`) is therefore below the minimum version
(`2.2.2`) specified by AWS.

#### Root Cause

`DC01` was running PSReadLine `2.0.0`, which does not meet the documented
minimum PSReadLine version required for the Fleet Manager PowerShell
keyboard functionality being used.

#### Planned Remediation

`DC01` intentionally has no public IP address or general Internet egress.
Installing the newer module directly from PowerShell Gallery would therefore
require introducing Internet connectivity.

Rather than adding general Internet egress solely for this dependency, I
plan to:

1. Obtain the required PSReadLine package from an Internet-connected system.
2. Store the package in a private Amazon S3 bucket.
3. Create an S3 Gateway VPC endpoint for private S3 connectivity.
4. Grant the EC2 instance role only the S3 permissions required to retrieve
   the package.
5. Retrieve and install the newer PSReadLine version on `DC01`.
6. Verify that PSReadLine `2.2.2` or later is installed.
7. Reconnect through Fleet Manager and confirm that PowerShell keyboard
   input functions correctly.

The S3 Gateway endpoint will allow resources in the private subnet to
access Amazon S3 without requiring a NAT Gateway, Internet Gateway path,
or public IP address.

Access will remain controlled at multiple layers:

- The S3 bucket will remain private.
- The S3 Gateway endpoint will be associated only with the route table
  used by the private subnet.
- The EC2 instance role will be granted only the S3 permissions required
  to retrieve the remediation package.
- General Internet egress will remain unavailable to `DC01`.

This approach introduces only the AWS service connectivity required to
solve the identified dependency rather than providing unrestricted
Internet access to the Domain Controller.

The final resolution and validation evidence will be added after the
remediation has been tested.

## Validation / Evidence
coming...

## Production Considerations

### Domain Controller Internet Connectivity

- A production Domain Controller should not be directly exposed to the Internet. However, controlled outbound connectivity may be required for operational dependencies such as patching and software retrieval. One option is private-subnet Internet egress through a NAT Gateway, combined with appropriate network and application-layer controls.

## Outcome / Lessons Learned
[Complete when the project is finished]

## Project Status

🚧 In Progress
