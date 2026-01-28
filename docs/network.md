**Network Composition**

The network is built inside s single AWS VPC. Within the VPC, separate private subnets are created for each department:
- NOC (IT)
- HR
- Acounting

Each subnet represents its own security zone. Instances in one subnet cannot directly communicate with instances in another unless explicitly allowed.
A single public subnet hosts the bastion server. All other instances live inside the private subnets and do not have public IP addresses.

**Gateways**

Internet gateway: Provides Internet access for the resources in the public subnet (the bastion host).
This lab does not use a NAT Gateway. Private subnets stay private. Where private instances need to reach AWS-managed services, the design relies on VPC endpoints (see endpoints.tf) instead of general Internet egress.

