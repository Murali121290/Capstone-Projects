#!/bin/bash
# usage: ./aws_stop_instances.sh <instance-id>
if [ -z "$1" ]; then
  echo "Usage: $0 <instance-id>"
  exit 1
fi
aws ec2 stop-instances --instance-ids $1 --region ${AWS_REGION:-us-east-1}
