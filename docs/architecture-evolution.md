# Architecture Evolution

This document records how the architecture changed and why. It complements the accompanying Medium and Dev.to article rather than repeating it: the article tells the story from the perspective of the engineer whose work was reviewed, while this document traces the technical decisions in the order they were made. Where the article dwells on the experience, this dwells on the reasoning.

### 1. Original Architecture

The first design was a segmented VPC with a bastion host and tightly scoped IAM roles. Three department workstations sat in private subnets. A single bastion in a public subnet was the only entry point. It worked, and it delivered real segmentation: private instances had no public IPs, and each department's IAM role reached only its own S3 bucket.

Two design decisions carried the administrative model. Every private instance shared one security group that trusted the bastion. And every instance, including the bastion, trusted one master key pair.

### 2. Security Review

The design was working, so the review was not looking for a broken control. It was looking at the shape of the trust the working controls produced. That is a different kind of examination, and it is the one that surfaced the issue.

### 3. Question Raised

One question did the work: what prevents an HR employee who has reached the bastion from SSHing to the Accounting workstation directly?

In the original design, nothing meaningful did. The master key the employee used to reach the bastion was the same key the Accounting instance trusted. The shared security group already consented to bastion-sourced traffic. The only thing between them and an Accounting shell was that they happened not to try.

### 4. Investigation

The instinct was that traversal would fail, so the first step was to test it rather than assume. Two observations came out of that.

The first confirmed that department-to-department traffic did fail. An attempt from one private instance to another was dropped by the shared security group, which trusted only the bastion. That isolation was real.

The second reframed the whole picture. The isolation was real, but it was pointed at the wrong thing. Every private instance's consent pointed at a single entity, the bastion, holding a single master key. The security group worked exactly as intended. The problem was not a faulty rule. It was that all of that correctly-functioning consent concentrated administrative trust in one place.

### 5. Evidence

The demonstration behind the investigation is documented in `validation.md`: the box-to-box attempt dropped by the shared security group, and the recognition that a bastion-sourced attempt using the master key would have succeeded. The lesson was not that the bastion was the problem. It was that too much administrative trust had accumulated within it.

### 6. Design Decisions

The correction had to keep the single point of entry while removing the single point of trust. That produced three decisions, each targeting one form of concentrated trust:

- Remove the static master key from the bastion, so perimeter access is ephemeral and identity-bound rather than a standing credential.
- Give each department its own key pair, so possession, not proximity to the bastion, decides which instance an operator can reach.
- Give each department its own security group, so a future rule change to one department cannot silently widen another, and instance-to-instance traversal stays closed.

### 7. Architecture Redesign

The three decisions became three layers. Layer 1 hardens the bastion with EC2 Instance Connect and maps entry to IAM identities. Layer 2 replaces the master key with per-department key pairs. Layer 3 replaces the shared security group with per-department groups. ProxyJump was adopted for the operator workflow so that department keys authenticate end-to-end without ever resting on the bastion.

The full design is described in `architecture.md`, and the build in `implementation-guide.md`.

### 8. Terraform Modifications

Six files carried the change. `bastion.tf` lost its `key_name`. `iam_operators.tf` and `keys.tf` were added for the operator identities and department key pairs. `instances.tf` was rewired to per-department keys and security groups. `main.tf` split the shared security group into three. `variables.tf` and `outputs.tf` were adjusted to match. Everything else, including the instance roles that were already correctly scoped, was left untouched.

### 9. Validation

Each layer was tested from the vantage point that exercises it: the intended path from the operator's machine, the wrong-key attempt from the bastion, and the lateral attempt from a department instance. The two failure modes proved distinct and observable, one a refused credential and one a dropped path. The details, including the honest limits of what the security groups and instance roles cover, are in `validation.md`.

### 10. Final Architecture

The bastion is now exactly what it should be: a network relay an operator passes through, not a trust anchor. There is no static credential on it, no persistent key tied to it on the operator's machine, and no forwarded agent socket to interact with. Entry is proven at each login and attributed to a name. Each department consents to a key only it holds. The single point of entry remains, and it is no longer a single point of trust.

### 11. Lessons Learned

**A working control can still be the problem** 
The shared security group did its job perfectly. The flaw was in what the job amounted to: universal consent to one over-trusted host. Reviewing what a control produces, not just whether it functions, is where this design improved.

**Trust concentrates quietly** 
No single decision created the master-key problem. A shared key and a shared group each seemed reasonable in isolation. Concentration was the emergent result. It surfaced only when someone asked where all the trust pointed.

**Segmentation is not one thing** 
The security groups segment networks. They do not segment identities arriving through a shared chokepoint. Separating those two ideas, and being explicit about which control does which, was the difference between a design that looks layered and one that is.

**Convenience trades against accountability** 
A single master key is convenient. Its cost is that no perimeter event carries a name. The corrected design spends a little operator friction, the 60-second window and per-department keys, to buy attribution and containment.

### 12. Future Enhancements

- Replace the per-department key pairs with an EC2 Instance Connect Endpoint, extending ephemeral, identity-bound access all the way to the private instances and retiring standing key material entirely.
- Front the assumable operator roles with an identity provider (SSO/SAML). The roles already remove long-lived operator credentials; federation would remove the static trust on a specific principal as well.
- Consider AWS Systems Manager as an alternative that removes inbound ports, key pairs, and the bastion altogether. The bastion remains a valid choice when implemented thoughtfully, and this project's purpose was to correct its trust model rather than sidestep it.
- Automate the boundary tests and add a dedicated CloudTrail trail with log-file validation.

### 13. Summary

`architecture-evolution.md` captures:

- The original design and the trust it quietly concentrated
- The single question that reframed a working demo as a question about power
- The three decisions that removed the concentration while keeping the entry point
- What the redesign taught, stated as lessons rather than conclusions
