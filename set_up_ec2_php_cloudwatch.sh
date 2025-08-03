#!/bin/bash
# Ensure script runs with Bash on macOS
[ -z "$BASH" ] && { echo "This script requires Bash. Run with /bin/bash"; exit 1; }

# Variables
IAM_ROLE_NAME="ZSR_CloudWatchAgentRole-$(date +%s)"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
REGION=$(aws configure get region || echo "eu-west-3")
TAG_NAME="ZSR_PHP-Web-Server"
SECURITY_GROUP_NAME="ZSR_php-web-sg-$(date +%s)"
KEY_PAIR_NAME="ZSR_php-web-keypair-$(date +%s)"
TERMINATION_DELAY=120 #seconds

# ./steps/test_iam.sh eg. calls the file here as a "function"

# 1. Create IAM Role for CloudWatch Agent
echo "Creating IAM Role: $IAM_ROLE_NAME"
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
echo "$TRUST_POLICY" > trust-policy.json
aws iam create-role --role-name "$IAM_ROLE_NAME" --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam create-instance-profile --instance-profile-name "$IAM_ROLE_NAME"
aws iam add-role-to-instance-profile --instance-profile-name "$IAM_ROLE_NAME" --role-name "$IAM_ROLE_NAME"
sleep 10  # Wait for IAM propagation
aws iam get-role --role-name "$IAM_ROLE_NAME"
echo "Created IAM Role: $IAM_ROLE_NAME"

# VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region "$REGION" --query Vpc.VpcId --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=$TAG_NAME-VPC
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION"
echo "Created VPC: $VPC_ID"

# Subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block $SUBNET_CIDR --availability-zone "${REGION}"a --query Subnet.SubnetId --output text)
if [ -z "$SUBNET_ID" ]; then
    echo "Error: Failed to create subnet in VPC $VPC_ID"
    exit 1
fi
aws ec2 create-tags --resources "$SUBNET_ID" --tags Key=Name,Value=$TAG_NAME-Subnet
echo "Created Subnet: $SUBNET_ID"

# NACL 
# Create NACL
NACL_ID=$(aws ec2 create-network-acl --vpc-id "$VPC_ID" --region "$REGION" --query 'NetworkAcl.NetworkAclId' --output text)
aws ec2 create-tags --resources "$NACL_ID" --tags Key=Name,Value=$TAG_NAME-NACL
echo "Created Network ACL: $NACL_ID"

# Inbound: allow SSH (22)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block 0.0.0.0/0 --rule-action allow

# Inbound: allow HTTP (80)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 110 --protocol tcp --port-range From=80,To=80 --cidr-block 0.0.0.0/0 --rule-action allow

# Inbound: allow HTTPS (443)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 120 --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow

# Inbound: allow ephemeral ports (1024–65535)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 130 --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow

# Outbound: allow HTTP (80)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --egress --rule-number 100 --protocol tcp --port-range From=80,To=80 --cidr-block 0.0.0.0/0 --rule-action allow

# Outbound: allow HTTPS (443)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --egress --rule-number 110 --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow

# Outbound: allow SSH (22)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --egress --rule-number 120 --protocol tcp --port-range From=22,To=22 --cidr-block 0.0.0.0/0 --rule-action allow

# Outbound: allow ephemeral ports (1024–65535)
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --egress --rule-number 130 --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow


# Replace default NACL association on the subnet
NACL_ASSOCIATION_ID_DEFAULT=$(aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --region "$REGION" \
  --query 'NetworkAcls[].Associations[?SubnetId==`'"$SUBNET_ID"'`].NetworkAclAssociationId' \
  --output text)

NACL_ASSOCIATION_ID_NEW=$(aws ec2 replace-network-acl-association \
  --association-id "$NACL_ASSOCIATION_ID_DEFAULT" \
  --network-acl-id "$NACL_ID" \
  --region "$REGION" \
  --query 'NewAssociationId' \
  --output text)

echo "Replaced NACL association: $NACL_ASSOCIATION_ID_NEW"

# Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value=$TAG_NAME-IGW
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
echo "Created and attached Internet Gateway: $IGW_ID"

# Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query RouteTable.RouteTableId --output text)
if [ -z "$ROUTE_TABLE_ID" ]; then
    echo "Error: Failed to create route table for VPC $VPC_ID"
    exit 1
fi
aws ec2 create-tags --resources "$ROUTE_TABLE_ID" --tags Key=Name,Value=$TAG_NAME-RouteTable
aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
ROUTE_TABLE_ASSOC_ID=$(aws ec2 associate-route-table --subnet-id "$SUBNET_ID" --route-table-id "$ROUTE_TABLE_ID" --query RouteTableAssociationId --output text)
if [ -z "$ROUTE_TABLE_ASSOC_ID" ]; then
    echo "Error: Failed to associate route table $ROUTE_TABLE_ID with subnet $SUBNET_ID"
    exit 1
fi
ROUTE_TABLE_ASSOC_ID=$(aws ec2 describe-route-tables --route-table-ids "$ROUTE_TABLE_ID" --query 'RouteTables[].Associations[].RouteTableAssociationId' --output text)
echo "Created Route Table: $ROUTE_TABLE_ID, Association ID: $ROUTE_TABLE_ASSOC_ID"


# Create Security Group
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Security group for PHP web server" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 create-tags --resources "$SECURITY_GROUP_ID" --tags Key=Name,Value=$TAG_NAME-SG
echo "Created Security Group: $SECURITY_GROUP_ID"

# Create Key Pair
if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "Error: Key pair $KEY_PAIR_NAME already exists"
    exit 1
fi
aws ec2 create-key-pair --key-name "$KEY_PAIR_NAME" --query 'KeyMaterial' --output text > "$KEY_PAIR_NAME.pem"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create key pair $KEY_PAIR_NAME"
    exit 1
fi
chmod 400 "$KEY_PAIR_NAME.pem"
echo "Created Key Pair: $KEY_PAIR_NAME"

# Launch EC2 Instance with User Data
INSTANCE_TYPE="t2.micro"
AMI_ID=$(aws ec2 describe-images --filters "Name=name,Values=amzn2-ami-hvm*" "Name=architecture,Values=x86_64" --region "$REGION" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)
if [ -z "$AMI_ID" ]; then
    echo "Error: Could not find AMI ID for region $REGION"
    exit 1
fi
echo "Using AMI ID: $AMI_ID"
USER_DATA=$(cat << 'EOF' | base64
#!/bin/bash
exec > /var/log/user-data.log 2>&1
yum update -y
yum install -y httpd php
systemctl start httpd
systemctl enable httpd
echo "<?php phpinfo(); ?>" > /var/www/html/index.php

# Install and configure CloudWatch Agent
yum install -y amazon-cloudwatch-agent
cat << 'AGENT_EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "namespace": "ZSR_PHP_Web_Server",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_active", "cpu_usage_idle"],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "devices": ["/"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "ZSR_PHP_Web_Access_Log",
            "log_stream_name": "{instance_id}/access_log"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "ZSR_PHP_Web_Error_Log",
            "log_stream_name": "{instance_id}/error_log"
          }
        ]
      }
    }
  }
}
AGENT_EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
EOF
)


INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_PAIR_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --iam-instance-profile Name="$IAM_ROLE_NAME" \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
  --region "$REGION" \
  --query Instances[0].InstanceId --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Error: Failed to launch EC2 instance"
    exit 1
fi
echo "Launched EC2 Instance: $INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "Instance is running"

# Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query Reservations[0].Instances[0].PublicIpAddress --output text)
if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Failed to get public IP for instance $INSTANCE_ID"
    exit 1
fi
echo "PHP Web Server is accessible at: http://$PUBLIC_IP"


# Wait before cleanup
echo "Waiting for $TERMINATION_DELAY seconds before cleanup..."
sleep $TERMINATION_DELAY

# Cleanup
echo "Cleaning up resources..."

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "Terminated EC2 Instance: $INSTANCE_ID"

# Delete CloudWatch Log Groups (optional)
aws logs delete-log-group --log-group-name ZSR_PHP_Web_Access_Log --region "$REGION" || echo "Log group ZSR_PHP_Web_Access_Log not found"
aws logs delete-log-group --log-group-name ZSR_PHP_Web_Error_Log --region "$REGION" || echo "Log group ZSR_PHP_Web_Error_Log not found"
echo "Deleted CloudWatch Log Groups"

# Route Table
aws ec2 disassociate-route-table --association-id "$ROUTE_TABLE_ASSOC_ID" --region "$REGION"
aws ec2 delete-route-table --route-table-id "$ROUTE_TABLE_ID" --region "$REGION"

# NACL
DEFAULT_NACL_ID=$(aws ec2 describe-network-acls \
  --filters Name=default,Values=true Name=vpc-id,Values="$VPC_ID" \
  --region "$REGION" \
  --query 'NetworkAcls[0].NetworkAclId' --output text)

aws ec2 replace-network-acl-association \
  --association-id "$NACL_ASSOCIATION_ID_NEW" \
  --network-acl-id "$DEFAULT_NACL_ID" \
  --region "$REGION"

aws ec2 delete-network-acl --network-acl-id "$NACL_ID" --region "$REGION"
echo "Deleted custom Network ACL: $NACL_ID"

#IGW
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region  "$REGION"
echo "Deleted Internet Gateway: $IGW_ID"

#subnet
aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$REGION"
echo "Deleted subnet: $SUBNET_ID"

#secgroup
aws ec2 delete-security-group --group-id "$SECURITY_GROUP_ID" --region "$REGION"
echo "Deleted Security Group: $SECURITY_GROUP_ID"

#vpc
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"
echo "Deleted VPC: $VPC_ID"

#iam 
aws iam remove-role-from-instance-profile --instance-profile-name "$IAM_ROLE_NAME" --role-name "$IAM_ROLE_NAME"
aws iam delete-instance-profile --instance-profile-name "$IAM_ROLE_NAME"
aws iam detach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam delete-role --role-name "$IAM_ROLE_NAME"

#key pair
aws ec2 delete-key-pair --key-name "$KEY_PAIR_NAME" --region "$REGION"
rm -f "$KEY_PAIR_NAME.pem"
rm -f trust-policy.json
echo "Deleted Key Pair: $KEY_PAIR_NAME"

echo "All resources cleaned up"