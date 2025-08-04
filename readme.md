# AWS PHP Web Server Deployment Script

This Bash script automates the full lifecycle of an AWS environment for running a PHP web server on EC2, including setup, monitoring, and teardown.

## What It Does

- Creates an IAM role for CloudWatch Agent
- Provisions a VPC, subnet, internet gateway, route table, and custom NACL
- Creates a security group and key pair
- Launches an EC2 instance running Apache + PHP
- Installs and configures CloudWatch Agent for logging and monitoring
- Waits (default 120s), then terminates the instance and deletes all created resources

## Requirements

- AWS CLI configured (`aws configure`)
- Bash (macOS or Linux)
- IAM permissions to manage EC2, IAM, and CloudWatch

## Usage

```bash
chmod +x set_up.sh
./set_up.sh
```

The script waits for 120 seconds after instance creation, then automatically cleans up all created resources.

## Output
EC2 instance with public IP running PHP (phpinfo() page)

Logs are visible in CloudWatch (during the run)

.pem file for SSH (deleted after run)

## Notes
AMI: latest Amazon Linux 2 (x86_64)

Key pairs, VPCs, and other resources are named uniquely with timestamps

The script deletes everything after $TERMINATION_DELAY (default: 120 seconds)

Designed for demo/testing purposes, not production use

## License
MIT
