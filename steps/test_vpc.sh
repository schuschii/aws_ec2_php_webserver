#!/bin/bash
REGION=""
REGION=$(aws configure get region || echo "eu-west-3")
export REGION
VPC_CIDR="10.0.0.0/16"
TAG_NAME="ZSR_PHP-Web-Server"
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region "$REGION" --query Vpc.VpcId --output text)
export VPC_ID
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=$TAG_NAME-VPC
echo "Created VPC: $VPC_ID"