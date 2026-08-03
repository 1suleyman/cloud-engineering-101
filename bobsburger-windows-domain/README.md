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

Architecture diagram: `architecture/architecture.drawio`

## Project Status

🚧 In Progress
