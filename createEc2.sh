#!/bin/bash

# This script creates instances and updates Route 53 records in AWS

instance=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web")
domain_name="daws93.online"
hosted_zone_id="Z0285612191R8C1OBNW9L"

for name in "${instance[@]}"; do
    if [ "$name" == "shipping" ] || [ "$name" == "mysql" ]; then
        instance_type="t3.micro"
    else    
        instance_type="t2.micro"
    fi
    
    echo "Creating instance for: $name with instance type: $instance_type"
    
    # Run the instance and capture the instance ID
    instance_id=$(aws ec2 run-instances --image-id ami-0220d79f3f480ecf5 --instance-type "$instance_type" --security-group-ids sg-0f4113cc012732160 --subnet-id subnet-0b58ea4566ed91360 --query 'Instances[0].InstanceId' --output text)

    # Debugging output to verify instance_id
    echo "Instance ID received: $instance_id"

    # Check if instance_id is valid
    if [ -z "$instance_id" ] || [ "$instance_id" == "None" ]; then
        echo "Error: Failed to retrieve Instance ID for $name. Skipping to next instance."
        continue
    fi
    
    echo "Instance created for $name with Instance ID: $instance_id"
    
    # Create tags for the instance
    aws ec2 create-tags --resources "$instance_id" --tags Key=Name,Value="$name"

    if [ "$name" == "web" ]; then
        aws ec2 wait instance-running --instance-ids "$instance_id"
        public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        ip_to_use="$public_ip"
    else
        private_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
        ip_to_use="$private_ip"
    fi
    
    # Debugging output to verify IP address
    echo "IP address for $name (instance $instance_id): $ip_to_use"

    if [ -z "$ip_to_use" ] || [ "$ip_to_use" == "None" ]; then
        echo "Error: Failed to retrieve IP address for instance $instance_id of $name. Skipping Route 53 update."
        continue
    fi
    
    echo "Creating Route 53 record for $name with IP: $ip_to_use"
    
    # Update Route 53 records
    aws route53 change-resource-record-sets --hosted-zone-id "$hosted_zone_id" --change-batch "
    {
        \"Comment\": \"Creating a record set for $name\",
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$name.$domain_name\",
                \"Type\": \"A\",
                \"TTL\": 1,
                \"ResourceRecords\": [{
                    \"Value\": \"$ip_to_use\"
                }]
            }
        }]
    }"
    
done

