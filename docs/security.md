**Security Layers**
Security is applied in layers rather than relying on a single control.

**Network Layer**
Private subnet prevents direct Internet access.
Security groups restrict traffic by source and port.
SSH access is only allowed through the bastion host.

**Identity Layer (IAM)**
EC2 instances assume IAM roles.
No static access keys are stored on instances.
Permissions are scoped to what each role needs to do.

**Access Control (PAM-lite)**
Administrative access funneled through the bastion.
SSH keys are required and centrally managed.
Access paths are narrow and auditable.
