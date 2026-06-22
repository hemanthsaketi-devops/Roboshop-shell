#!/bin/bash

instances=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web")

domain_name="daws93s.online"
hosted_zone_id="Z02671512D0FTHVVKN2M"

ami_id="ami-0220d79f3f480ecf5"
security_group_id="sg-0fea5e49e962e81c9"
subnet_id="subnet-0686896146c8f390b"

for name in "${instances[@]}"
do
if [[ "$name" == "shipping" || "$name" == "mysql" ]]
then
instance_type="t3.medium"
else
instance_type="t3.micro"
fi

```
echo "====================================================="
echo "Creating instance for: $name"
echo "Instance Type: $instance_type"
echo "====================================================="

instance_id=$(aws ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$instance_type" \
    --security-group-ids "$security_group_id" \
    --subnet-id "$subnet_id" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ -z "$instance_id" ] || [ "$instance_id" == "None" ]
then
    echo "Failed to create instance for $name"
    continue
fi

echo "Instance Created: $instance_id"

aws ec2 create-tags \
    --resources "$instance_id" \
    --tags Key=Name,Value="$name"

aws ec2 wait instance-running \
    --instance-ids "$instance_id"

if [ "$name" == "web" ]
then
    ip_to_use=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
else
    ip_to_use=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
fi

echo "IP Address: $ip_to_use"

echo "Creating Route53 record for $name"

aws route53 change-resource-record-sets \
    --hosted-zone-id "$hosted_zone_id" \
    --change-batch "{
        \"Comment\": \"Creating record for $name\",
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

echo "$name Route53 record created"
```

done

echo "All instances created successfully"
