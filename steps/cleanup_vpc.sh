#!/bin/bash
if [ -z "$VPC_ID" ]; then
    echo "Error: VPC_ID is not set"
    exit 1
fi
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"
echo "Deleted VPC: $VPC_ID"
