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
IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
export IGW_ID
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query RouteTable.RouteTableId --output text)
aws ec2 create-tags --resources "$ROUTE_TABLE_ID" --tags Key=Name,Value=$TAG_NAME-RouteTable
aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
ROUTE_TABLE_ASSOC_ID=$(aws ec2 associate-route-table --subnet-id "$SUBNET_ID" --route-table-id "$ROUTE_TABLE_ID" --query RouteTableAssociationId --output text)
export ROUTE_TABLE_ASSOC_ID
echo "Created Route Table: $ROUTE_TABLE_ID"
