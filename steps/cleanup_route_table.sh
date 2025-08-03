#!/bin/bash
if [ -z "$ROUTE_TABLE_ID" ]; then
    echo "Error: ROUTE_TABLE_ID is not set"
    exit 1
fi


aws ec2 delete-route-table --route-table-id "$ROUTE_TABLE_ID" --region "$REGION"
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$REGION"
aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$REGION"
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"
echo "Deleted Route Table: $ROUTE_TABLE_ID, Subnet: $SUBNET_ID, Internet Gateway: $IGW_ID, and VPC: $VPC_ID"
