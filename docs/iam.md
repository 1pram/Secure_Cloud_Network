IAM is used to control what each instance can access once it is running

**Role separation**
- NOC role: Read-Only access to CloudWatch logs
- HR role: Access only to the HR S3 bucket
- Accounting role: Access only to the accounting S3 bucket

Each role is attached to the appropriate EC2 instance profile. This keeps permissions isolated.

**Avoiding long-lived credentials**
Instances authenticate using temporary credentials issued by AWS through IAM roles. No passwords or access keys are embedded in code or stored on disk.