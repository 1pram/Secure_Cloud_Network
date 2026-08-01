# Architecture

The Secure Cloud Network is a segmented AWS environment where administrative access is bound to identity rather than to possession of a key. A single bastion host bridges the public internet to three private department workstations, but reaching the bastion no longer implies reaching what sits behind it. This document explains what the system is, what each component does, and which boundaries are intentional.

This is the corrected architecture. An earlier design concentrated administrative trust in the bastion through one shared security group and one master key pair. The review that followed, documented in `architecture-evolution.md`, is what produced the design described here.

### 1. Project Overview

The environment models a small organization with three departments: NOC (IT), HR, and Accounting. Each has its own private workstation, its own storage, and its own operator identity. None can reach another's instance by design.

The goal was a lab that is secure by default, cost-aware, and easy to reason about, without overengineering. Every control here exists to answer a specific question raised during the review, and each is scoped to do one thing rather than many.

### 2. High-Level Architecture

At a high level, an operator reaches a department workstation as follows:

1. The operator pushes a short-lived SSH key to the bastion through EC2 Instance Connect, authorized against their IAM identity.
2. AWS validates the identity and, if permitted, writes the key to the bastion's authorized_keys for 60 seconds.
3. The operator connects with ProxyJump, tunneling through the bastion to their department instance in a single command.
4. The department key, held only by that operator, authenticates end-to-end to the department instance.
5. IAM roles on the instance grant scoped access to that department's S3 storage.
6. CloudTrail records the entry attempt under the operator's identity.

The result is a design where entry is an authorization event tied to a name, not a standing network path guarded by a shared secret. Also, with the initial SSH request mapped to its author via IAM assummable roles, monitoring systems such as CloudTrail (not configured in this lab, default management-event trail only) can have visibility over the entire access sequence outlined above. This is now a fully attributable event.

### 3. Core AWS Services

This project uses the following AWS services:

- **Amazon VPC**: Network boundary housing one public subnet and three private department subnets.
- **Amazon EC2 (Bastion Host)**: Single controlled entry point into the private subnets. Carries no static key.
- **Amazon EC2 (Department Workstations)**: NOC, HR, and Accounting instances, each in its own private subnet with its own key pair.
- **EC2 Instance Connect**: Pushes ephemeral, identity-bound SSH keys to the bastion in place of a static key.
- **AWS IAM**: Instance roles scoped per department, plus operator identities that authorize entry at the perimeter.
- **Amazon S3 (Department buckets)**: HR and Accounting storage, each reachable only by its own department's instance role.
- **AWS CloudTrail**: Records SendSSHPublicKey calls, attributing every perimeter entry attempt to a named principal.
- **VPC Endpoints**: Allow private instances to reach AWS services without a NAT gateway or public internet exposure.

### 4. Network Segmentation

The VPC uses a four-subnet model:

- **Public subnet** Hosts the bastion host, reachable from the administrator's IP via the internet gateway.
- **NOC private subnet** Hosts the NOC workstation, no direct internet route.
- **HR private subnet** Hosts the HR workstation, no direct internet route.
- **Accounting private subnet** Hosts the Accounting workstation, no direct internet route.

Each private subnet is its own security zone. The route between subnets exists, because AWS creates a local route within a VPC by default and it cannot be removed. What is missing is permission. Separation is enforced at the security group, not the route table.

### 5. Identity Model

Identity governs two separate things: what each instance can do once running, and which humans may reach the perimeter.

### Instance Roles

- **NOC role** Read-only access to CloudWatch logs.
- **HR role** Access only to the HR S3 bucket.
- **Accounting role** Access only to the Accounting S3 bucket.

Each role is attached to its instance through an instance profile. No static access keys are stored on any instance.

### Operator Identities

- **noc-operator, hr-operator, acct-operator** One assumable IAM role per department.
- Each role trusts the operator principal and is entered through STS.

Each role carries a single policy, BastionEICConnect, permitting exactly one action: push a short-lived key to the bastion, as ec2-user. Because the call is made from an assumed-role session, CloudTrail records which role attempted entry and when, with no long-lived operator credential involved.

### 6. Administrative Model

All administrative access funnels through the bastion. There is no direct route from the internet to any department workstation.

The bastion is a network relay an operator passes through, not a trust anchor. It holds no credential of its own. Access to it is a short-lived, identity-bound event through EC2 Instance Connect. Reaching a department instance past it requires that department's key, held only by that department's operator.

### 7. Bastion Design

The bastion is intentionally minimal:

- No static key pair. The `key_name` argument is omitted, so nothing persistent grants access.
- EC2 Instance Connect, preinstalled on Amazon Linux 2, injects an ephemeral key valid for 60 seconds when an authorized operator calls SendSSHPublicKey.
- Operators reach department instances through ProxyJump, which uses the bastion as an encrypted relay only. Department keys never touch its disk, and no agent socket is left on it.

An operator who skips the EC2 Instance Connect step finds the bastion's authorized_keys empty and fails at the first hop. EC2 Instance Connect is not a gate in front of the bastion. It is the only thing that makes the bastion reachable at all.

### 8. Trust Boundaries

Three boundaries separate a department's resources from everything else:

- **Perimeter (Layer 1)** Who reaches the bastion, and under what name, is governed by IAM and EC2 Instance Connect.
- **Credential (Layer 2)** Reaching a department instance requires that department's key pair. Possession is scoped per department.
- **Network (Layer 3)** Each department security group permits SSH from the bastion only. No rule permits department-to-department traffic.

These boundaries are independent. Where each one stops is spelled out in `validation.md`, because they do not all fire on the same attempt, and stating so honestly is part of the design.

### 9. Data Flow

A legitimate operator session flows in one direction:

1. Operator identity is validated by IAM against the BastionEICConnect policy.
2. An ephemeral key is written to the bastion for 60 seconds.
3. ProxyJump tunnels through the bastion to the department instance.
4. The department key authenticates end-to-end to the instance.
5. The instance role grants scoped access to that department's S3 bucket.
6. CloudTrail records the SendSSHPublicKey call under the operator's identity.

Traffic never flows department-to-department. A workstation cannot initiate a session into another department's subnet, because no security group permits it.

### 10. Architectural Decisions

**Bastion retained rather than replaced** 
AWS Systems Manager would remove inbound ports, key pairs, and the bastion entirely. The bastion was kept deliberately, both because it is a valid pattern when implemented thoughtfully and because the project's purpose was to correct the bastion's trust model, not sidestep it. The trade-off is noted in `architecture-evolution.md`.

**No static key on the bastion** 
A static key pair on a shared entry point is a single credential whose theft compromises the perimeter. EC2 Instance Connect replaces it with ephemeral, attributable keys. The trade-off is a 60-second connection window that operators must respect.

**Per-department key pairs instead of one master key** 
A single master key trusted by every instance means reaching the bastion reaches everything. Per-department keys make possession the boundary. The trade-off is three key pairs to generate, distribute, and eventually rotate.

**ProxyJump instead of agent forwarding** 
Agent forwarding leaves a socket on the bastion that a root-level attacker could reach through. ProxyJump uses the bastion as a blind relay, so no department credential is exposed on it. This is a client-side choice and requires no infrastructure change.

**Security groups as a blast-radius control, not a department gate** 
The department security groups close instance-to-instance traversal and limit the impact of a future rule change. They do not separate departments arriving from the bastion, which every department group trusts equally. On that path the department key is the control. This distinction is deliberate and documented rather than glossed.

### 11. Diagrams

- **Architecture diagram** See `Diagram/`. Shows the VPC, public and private subnets, the bastion, the three workstations, and the S3 and CloudWatch destinations.
- **Trust-model data flow (placeholder)** A before-and-after data flow diagram of the bastion's trust model belongs here. The "before" shows universal consent pointing at a single master key. The "after" shows identity proven at each login and per-department key consent. *To be added.*

### 12. Summary

`architecture.md` captures:

- What the system is and what each component does
- How the network, identity, and administrative layers fit together
- Which boundaries are intentional and where each one stops
- Why the bastion was corrected rather than removed
