**Project Overview**

This project is a hands-on Infrastructure as Code (IaC) built with Terraform. The goal was to design a small but realistic AWS environment that is secure by default, cost-aware, and easy to reason about as a first-time cloud security endeavor.

The environment uses a segmented VPC, a bastion host for controlled access, and tightly scoped IAM roles. Each design choice was made to reflect real-world security tradeoffs without overengineering.

**What this project demonstrates**

Network segmentation to reduce lateral movement
Controlled administrative access using a bastion host
IAM roles instead of long-lived credentials
Least-privilege access per department
Repeatable and auditable infrastructure using Terraform

**Cost considerations**
- All EC2 instances use t2.micro
- Internet Gateway only (no NAT Gateway)
- Ises VPC endpoints where needed instead of paid egress patterns
- No paid security services
- Uses native AWS features wherever possible

This keeps the environment within free-tier or near-free-tier limits for learning purposes.

**Closing Notes**

This project prioritizes clarity over complexity. The focus is on understanding why each control exists, not just how to deploy it. It is intended as a foundation that can be expanded later with services like an instance/station (used for patch management), system Manager, session logging, or centralized monitoring.