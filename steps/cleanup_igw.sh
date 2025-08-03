#!/bin/bash
if [ -z "$IGW_ID" ]; then
    echo "Error: IGW_ID is not set"
    exit 1
fi

aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region  "$REGION"
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region  "$REGION"
echo "Deleted Internet Gateway: $IGW_ID and VPC: $VPC_ID"