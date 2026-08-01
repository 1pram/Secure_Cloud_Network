# Validation

This document records how the corrected architecture was validated. It states, for each control, the behavior the design predicts and the behavior observed when tested. The aim is repeatable checks with clear pass or fail outcomes, and an honest account of what each control does and does not do.

One point governs the whole exercise: the three layers do not all fire on the same attempt. Depending on where traffic originates, a given attempt is stopped by a different layer. Naming which layer stops which attempt is the substance of this validation, not a footnote to it.

### 1. Validation Methodology

Each control is tested by attempting the action it is meant to permit, then attempting the action it is meant to prevent, and comparing the result to the prediction. Tests run from three vantage points, because the vantage point determines which layer is exercised:

- From the operator's local machine, through the intended EC2 Instance Connect and ProxyJump path.
- From the bastion, simulating an operator who has legitimately reached it.
- From a department instance, simulating a compromised workstation attempting lateral movement.

### 2. SSH Testing

**Test 1: Intended path succeeds** 
Load the HR key, push an ephemeral key to the bastion, and ProxyJump to the HR instance.

```
ssh-add keys/hr-key
aws ec2-instance-connect send-ssh-public-key --instance-id <bastion_id> \
  --availability-zone <az> --instance-os-user ec2-user --ssh-public-key file://temp-key.pub
ssh -J ec2-user@<bastion_public_ip> ec2-user@<hr_private_ip>
```

Expected: successful login to the HR instance. Confirms the full Layer 1 to Layer 2 path for the correct operator.

**Test 2: Skip the EC2 Instance Connect step** 
Attempt the ProxyJump without first pushing an ephemeral key.

```
ssh -J ec2-user@<bastion_public_ip> ec2-user@<hr_private_ip>
```

Expected: failure at the first hop. The bastion's authorized_keys is empty, so the bastion itself is unreachable. Confirms EC2 Instance Connect is what makes the bastion reachable, not a gate in front of it.

**Test 3: Wrong department key from the bastion** 
As an operator on the bastion holding only the HR key, attempt to reach the Accounting instance.

```
ssh ec2-user@<acct_private_ip>
```

Expected: authentication fails during negotiation. This is the Layer 2 wall. The traffic is sourced from the bastion, which the Accounting security group permits, so the packet reaches sshd and the handshake begins. It is refused because the HR key finds no match in the Accounting instance's authorized_keys.

**Test 4: Lateral movement between departments** 
From the HR instance, attempt to reach the Accounting instance directly.

```
ssh ec2-user@<acct_private_ip>
```

Expected: the connection is dropped before a TCP session opens. This is the Layer 3 wall. The traffic is sourced from the HR instance, which the Accounting security group does not permit, so sshd never sees it.

**Test 5: Ephemeral key expiry** 
Push an ephemeral key, wait 60 seconds, then attempt to connect.

Expected: failure at the first hop. The key has expired and the bastion's authorized_keys has returned to empty.

### 3. ssh -vvv Analysis

Running the wrong-key attempt from Test 3 with verbose output shows the connection reaching the Accounting instance and failing at authentication, not at the network.

```
ssh -vvv ec2-user@<acct_private_ip>
```

Expected in the trace: the TCP connection to port 22 succeeds and key exchange begins, followed by the server rejecting the offered HR key and the negotiation ending without a shell. This distinguishes a Layer 2 failure (delivered, then denied at authentication) from a Layer 3 failure (never delivered). The verbose log is the evidence that the packet arrived.

### 4. tcpdump Analysis

Running the lateral-movement attempt from Test 4 while capturing on the Accounting instance shows the opposite signature.

```
sudo tcpdump -n -i any port 22
```

Expected on the Accounting instance: no inbound packets from the HR instance's private IP appear at all. The security group dropped the traffic before it reached the interface. Contrast with Test 3, where packets from the bastion do arrive. The capture is the evidence that distinguishes a dropped path from a refused credential.

### 5. Security Group Validation

The Layer 3 claim is that department separation for instance-to-instance traffic comes from the absence of a permit rule, not an explicit deny.

Inspect the Accounting security group and confirm its only ingress rule permits the bastion security group as source, with no rule referencing the HR or NOC groups.

```
aws ec2 describe-security-groups --group-ids <acct_sg_id> \
  --query "SecurityGroups[0].IpPermissions"
```

Expected: a single SSH ingress rule sourced from the bastion security group. No department-to-department permit exists, which is what makes the lateral attempt in Test 4 fail.

### 6. Expected Behavior

- Correct operator, correct key: reaches their department instance.
- Any operator, no EC2 Instance Connect push: cannot reach the bastion.
- Operator on the bastion, wrong department key: reaches the target instance's sshd, fails authentication.
- Compromised workstation, lateral attempt: dropped before sshd.
- Expired ephemeral key: cannot reach the bastion.

### 7. Observed Behavior

Observed results matched predictions across the SSH tests, the verbose trace, and the packet capture. The two failure modes are distinct and observable: a Layer 2 failure shows delivery followed by authentication rejection, and a Layer 3 failure shows no delivery. This confirms the walls are independent and that each governs a different origin of traffic.

### 8. Evidence

- `ssh -vvv` output for the wrong-key attempt, showing connection then authentication failure.
- `tcpdump` capture on the Accounting instance, showing no packets during the lateral attempt and bastion-sourced packets during the wrong-key attempt.
- `describe-security-groups` output showing the single bastion-sourced ingress rule.
- CloudTrail entries for SendSSHPublicKey, attributed to the assumed operator role session (for example hr-operator).

*Screenshots of these results belong in `Diagram/` or a `diagrams_and_screenshots/` folder and are to be added.*

### 9. Known Limitations

**Instance roles protect buckets, not shells** 
IAM scopes each instance role to its own department bucket, and that separation holds. It does not, on its own, contain a human. An operator who obtains a shell on the Accounting instance inherits the Accounting role and its bucket access. The validated S3 denial was tested from the HR instance, which proves role separation, not human containment. Containment of the human is what Layers 1 through 3 provide by keeping the wrong operator off the Accounting shell in the first place.

**Security groups do not separate departments arriving from the bastion** 
Every department group trusts the bastion equally. For an operator on the bastion, the security group is not a wall. The department key is. Test 3 and Test 4 exercise these two different origins deliberately, and the distinction is intentional rather than a gap.

**Validation is manual** 
The tests above are run by hand. There is no automated test harness or CI pipeline asserting these outcomes on each change.

**Terraform validate and plan** 
These were not run in the authoring environment. Run `terraform validate` and `terraform plan` against the tree before relying on it.

### 10. Future Validation

- Automate the boundary tests so each `terraform apply` is followed by a repeatable pass or fail run.
- Add a dedicated CloudTrail trail with log-file validation, then confirm each SendSSHPublicKey event resolves to the expected assumed-role session (noc-operator, hr-operator, acct-operator).
- Extend the S3 test to the human-containment case: obtain a shell on a department instance and confirm exactly what the inherited role can and cannot reach, documenting the boundary rather than implying it.
- Capture and commit the evidence artifacts referenced in section 8.

### 11. Summary

`validation.md` captures:

- How each control was tested, and from which vantage point
- What the design predicts and what was observed
- Which layer stops which attempt, and why that depends on origin
- What the controls do not cover, stated plainly
