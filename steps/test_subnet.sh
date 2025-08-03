#!/bin/bash
REGION=$(aws configure get region || echo "eu-west-3")
export REGION
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
TAG_NAME="ZSR_PHP-Web-Server"

VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region "$REGION" --query Vpc.VpcId --output text)
export VPC_ID
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=$TAG_NAME-VPC
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block $SUBNET_CIDR --availability-zone "${REGION}"a --query Subnet.SubnetId --output text)
export SUBNET_ID
aws ec2 create-tags --resources "$SUBNET_ID" --tags Key=Name,Value=$TAG_NAME-Subnet
echo "Created Subnet: $SUBNET_ID"