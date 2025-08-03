#!/bin/bash
if [ -z "$SUBNET_ID" ]; then
    echo "Error: SUBNET_ID is not set"
    exit 1
fi

aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$REGION"
aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"
echo "Deleted subnet: $SUBNET_ID"