#!/bin/bash
# No BASH check to avoid exiting in Zsh
echo "Running test_iam.sh in shell: $SHELL"

IAM_ROLE_NAME="ZSR_CloudWatchAgentRole-$(date +%s)"
export IAM_ROLE_NAME # Ensure IAM role name is unique by appending timestamp + exporting to environment
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
echo "$TRUST_POLICY" > trust-policy.json
aws iam create-role --role-name "$IAM_ROLE_NAME" --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam create-instance-profile --instance-profile-name "$IAM_ROLE_NAME"
aws iam add-role-to-instance-profile --instance-profile-name "$IAM_ROLE_NAME" --role-name "$IAM_ROLE_NAME"
echo "Created IAM Role: $IAM_ROLE_NAME"