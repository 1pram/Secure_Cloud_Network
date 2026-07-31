# Implementation Guide

This guide describes how the corrected architecture is built, organized by the three layers that produce it. For each layer, the reasoning comes first, then the Terraform that implements it. The layers are interdependent but separable: Layer 1 governs who reaches the bastion, Layer 2 governs which department instance they can authenticate to, and Layer 3 governs which network paths exist at all.

### Prerequisites

- Terraform installed
- AWS account
- AWS CLI configured (used by EC2 Instance Connect)
- Three department key pairs generated locally (see below)
- A text editor (Notepad, VIM etc.) or an IDE like VSCode

### Terraform Deployment

The three layers deploy together as one Terraform configuration. Before applying, generate one key pair per department. Each department instance will trust only its own public key, so the single master key of the original design no longer exists.

```
mkdir -p keys
ssh-keygen -t ed25519 -f keys/noc-key  -C noc
ssh-keygen -t ed25519 -f keys/hr-key   -C hr
ssh-keygen -t ed25519 -f keys/acct-key -C acct
```

Distribute each private key only to the operators authorized for that department. Terraform reads the .pub files only.

```
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

### 1. Layer 1: Hardening the Bastion with EC2 Instance Connect

**Reasoning** 
The bastion remains the designated chokepoint bridging a controlled path to the private instances, but that role makes its trust model a disproportionately high-value target. A static key pair on the bastion is a single credential whose theft opens the perimeter. Removing it and replacing it with ephemeral, identity-bound keys means there is no long-lived credential to steal, and every entry attempt carries a name.

**Implementation** 
The bastion sheds its static key. The `key_name` argument is removed, and the ec2-instance-connect package that ships with Amazon Linux 2 takes over key handling at connection time.

```
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.amzn2.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_bastion.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name

  tags = { Name = "bastion" }
}
```

### EC2 Instance Connect

**Reasoning** 
EC2 Instance Connect is not a gate placed in front of an otherwise-reachable bastion. With no static key present, it is the only thing that makes the bastion reachable at all. The mechanism pairs a temporary key with an identity check, so authentication and authorization are evaluated together, before any key touches the host.

**How it works**

- After generating a temporary key locally, the operator makes an API call, SendSSHPublicKey, via `aws ec2-instance-connect`.
- AWS validates the identity making the request. If the operator's policy allows this action on this specific instance, the key is written to the bastion's authorized_keys, where it lives for 60 seconds.
- The operator must SSH immediately, before the window closes (see the access workflow below).

### IAM

**Reasoning** 
Each department gets an assumable IAM role rather than a standing user, so entry is attributable without any long-lived operator credential. A tightly scoped policy lets the role do exactly one thing: push a short-lived key to the bastion, as ec2-user. Pinning the policy to the bastion ARN means the same grant cannot be quietly turned against a private instance, and the ec2:osuser condition prevents landing as another user.

**Implementation**

```
data "aws_iam_policy_document" "operator_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [local.operator_principal]
    }
  }
}

resource "aws_iam_role" "hr_operator" {
  name               = "hr-operator"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = { Department = "HR", Purpose = "BastionOperator" }
}

resource "aws_iam_policy" "bastion_eic_connect" {
  name = "BastionEICConnect"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "ec2-instance-connect:SendSSHPublicKey",
      Resource  = aws_instance.bastion.arn,
      Condition = { StringEquals = { "ec2:osuser" = "ec2-user" } }
    }]
  })
}
```

The remaining department roles follow the same pattern, each with the same EIC grant attached. Because the call is recorded in CloudTrail under the individual, every event at the perimeter finally carries a name, something a shared master key could never provide.

### 2. Layer 2: Department-Specific Credentials

**Reasoning** 
With one master key, reaching the bastion effectively reached every instance. Giving each department its own key pair makes possession the boundary. Even when the bastion is reached, an additional department-specific credential is required to authenticate to a private instance. From the bastion to the Accounting instance, the correct IP with the wrong key fails authentication.

**Implementation**

```
resource "aws_key_pair" "noc_key" {
  key_name   = "noc-key"
  public_key = file(var.noc_public_key_path)
}

resource "aws_key_pair" "hr_key" {
  key_name   = "hr-key"
  public_key = file(var.hr_public_key_path)
}

resource "aws_key_pair" "acct_key" {
  key_name   = "acct-key"
  public_key = file(var.acct_public_key_path)
}
```

Each department instance references its own key pair through `key_name`, so its authorized_keys is written once from a single public key.

### 3. Layer 3: Department-Specific Security Groups

**Reasoning** 
Instead of one shared private security group, each department gets its own. AWS security groups are deny by default, and there is no explicit deny syntax. You cannot write a rule that blocks HR from reaching Accounting. What you do instead is never write a rule that permits it. The absence of a cross-department permit rule is itself the enforcement mechanism.

This layer limits blast radius and closes instance-to-instance traversal. It does not separate departments arriving from the bastion, which every department group trusts equally. That distinction is validated in `validation.md`.

**Implementation**

```
resource "aws_security_group" "noc_private_sg" {
  name        = "noc-private-sg"
  description = "Allow SSH from bastion only - NOC department"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "noc-private-sg" }
}
```

The same pattern applies to hr_private_sg and acct_private_sg.

### 4. ProxyJump

**Reasoning** 
Reaching a department instance from the bastion needs that department's key. If the key were copied onto the bastion, or forwarded through an agent socket on it, the bastion would again hold something worth stealing. ProxyJump avoids both. It uses the bastion as an encrypted relay, so the department key authenticates end-to-end from the operator's machine directly to the department instance. The bastion sees encrypted bytes it cannot inspect and holds no credential of its own.

ProxyJump is client-side SSH behavior. It requires no infrastructure change and lives only in the operator workflow.

**Implementation**

```
ssh -J ec2-user@<bastion_public_ip> ec2-user@<department_private_ip>
```

### 5. CloudTrail

**Reasoning** 
Attribution is only useful if it is recorded. The SendSSHPublicKey call is evaluated against the assumed-role session, and CloudTrail captures it under that role, for example hr-operator. Same perimeter, distinct names. The audit trail knows who attempted entry.

CloudTrail configuration for this lab relies on the account's default management-event trail. Dedicated trail resources and log-file validation are noted as future work in `validation.md`.

### 6. Terraform Changes

Six files carry the correction. Everything else is untouched from the original design.

- **bastion.tf** `key_name` removed. EC2 Instance Connect brokers access.
- **iam_operators.tf** New. Assumable operator roles, their trust policy, and the BastionEICConnect policy.
- **keys.tf** New. Three aws_key_pair resources.
- **instances.tf** Each workstation wired to its own key pair and its own department security group.
- **main.tf** The shared private_ssh_sg replaced by noc_private_sg, hr_private_sg, and acct_private_sg.
- **variables.tf** key_pair_name dropped in favor of noc_public_key_path, hr_public_key_path, and acct_public_key_path.
- **outputs.tf** bastion_instance_id added, needed for the SendSSHPublicKey call.

### 7. Deployment Walkthrough

The day-to-day access flow is two steps and two credentials. Reaching the bastion no longer means reaching what sits behind it.

1. Load your department key into the local agent. It authenticates end-to-end and never reaches the bastion.

```
ssh-add keys/hr-key
```

2. Assume your department's operator role, then push an ephemeral key to the bastion. It lives for 60 seconds.

```
eval "$(aws sts assume-role \
  --role-arn <hr_operator_role_arn> \
  --role-session-name hr-admin \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')"

aws ec2-instance-connect send-ssh-public-key \
  --instance-id <bastion_instance_id> \
  --availability-zone <az> \
  --instance-os-user ec2-user \
  --ssh-public-key file://temp-key.pub
```

3. Connect immediately, reaching the department instance in a single command.

```
ssh -J ec2-user@<bastion_public_ip> ec2-user@<department_private_ip>
```

bastion_instance_id and bastion_public_ip come from `terraform output`. An operator who skips step 2 finds the bastion's authorized_keys empty and fails at the first hop.

### 8. Cleanup

Tear down the environment after use to avoid ongoing charges:

```
terraform destroy
```

Remove the locally generated key material as well once the environment is gone:

```
rm -rf keys
```

### 9. Summary

`implementation-guide.md` captures:

- How each layer is built, reasoning first, then Terraform
- How EC2 Instance Connect, IAM, and ProxyJump combine into one access flow
- Which files changed and what each change does
- How to deploy, connect, and tear down
