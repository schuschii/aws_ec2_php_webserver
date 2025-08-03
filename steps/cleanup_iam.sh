#!/bin/bash
if [ -z "$IAM_ROLE_NAME" ]; then
    echo "Error: IAM_ROLE_NAME is not set"
    exit 1
fi
aws iam remove-role-from-instance-profile --instance-profile-name "$IAM_ROLE_NAME" --role-name  "$IAM_ROLE_NAME"
aws iam delete-instance-profile --instance-profile-name  "$IAM_ROLE_NAME"
aws iam detach-role-policy --role-name  "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam delete-role --role-name  "$IAM_ROLE_NAME"
rm -f trust-policy.json
echo "Removed IAM Role: $IAM_ROLE_NAME"