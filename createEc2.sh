#!/bin/bash

# Roboshop EC2 Creation Script

instances=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web")

domain_name="daws93s.online"
hosted_zone_id="Z02671512D0FTHVVKN2M"
ami_id="ami-0220d79f3f480ecf5"

echo "Getting AWS Resources..."

# Get Default VPC

vpc_id=$(aws ec2 describe-vpcs 
--filters "Name=isDefault,Values=true" 
--query 'Vpcs[0].VpcId' 
--output text)

# Get Default Subnet

subnet_id=$(aws ec2 describe-subnets 
--filters "Name=default-for-az,Values=true" 
--query 'Subnets[0].SubnetId' 
--output text)

# Get Default Security Group

security_group_id=$(aws ec2 describe-security-groups 
--filters "Name=vpc-id,Values=$vpc_id" 
"Name=group-name,Values=default" 
--query 'SecurityGroups[0].GroupId' 
--output text)

echo "VPC ID            : $vpc_id"
echo "Subnet ID         : $subnet_id"
echo "Security Group ID : $security_group_id"

for name in "${instances[@]}"
do

```
if [[ "$name" == "mysql" || "$name" == "shipping" ]]
then
    instance_type="t3.micro"
else
    instance_type="t2.micro"
fi

echo "====================================================="
echo "Creating Instance : $name"
echo "Instance Type     : $instance_type"
echo "====================================================="

instance_id=$(aws ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$instance_type" \
    --security-group-ids "$security_group_id" \
    --subnet-id "$subnet_id" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance ID : $instance_id"

if [[ -z "$instance_id" || "$instance_id" == "None" ]]
then
    echo "Failed to create instance for $name"
    continue
fi

aws ec2 create-tags \
    --resources "$instance_id" \
    --tags Key=Name,Value="$name"

echo "Waiting for instance to be running..."

aws ec2 wait instance-running \
    --instance-ids "$instance_id"

if [[ "$name" == "web" ]]
then
    ip_address=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
else
    ip_address=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
fi

echo "IP Address : $ip_address"

if [[ -z "$ip_address" || "$ip_address" == "None" ]]
then
    echo "Failed to get IP for $name"
    continue
fi

echo "Creating Route53 Record..."

aws route53 change-resource-record-sets \
    --hosted-zone-id "$hosted_zone_id" \
    --change-batch "{
        \"Comment\":\"Creating record for $name\",
        \"Changes\":[
            {
                \"Action\":\"UPSERT\",
                \"ResourceRecordSet\":{
                    \"Name\":\"$name.$domain_name\",
                    \"Type\":\"A\",
                    \"TTL\":1,
                    \"ResourceRecords\":[
                        {
                            \"Value\":\"$ip_address\"
                        }
                    ]
                }
            }
        ]
    }"

echo "$name DNS record created successfully"
```

done

echo "All instances processed successfully."


