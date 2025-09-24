#!/bin/bash
# usage: ./aws_start_instances.sh <instance-id>
if [ -z "$1" ]; then
  echo "Usage: $0 <instance-id>"
  exit 1
fi
aws ec2 start-instances --instance-ids $1 --region ${AWS_REGION:-us-east-1}
aws ec2 describe-instances --instance-ids $1 --region ${AWS_REGION:-us-east-1} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
