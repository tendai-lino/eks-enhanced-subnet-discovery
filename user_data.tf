# =========================================
# NAT66 Auto-Scaling Module - User Data
# =========================================

locals {
  nat66_user_data = <<-EOF
    #!/bin/bash
    set -xe

    REGION="${var.region}"
    RT_TAG_KEY="${var.pvt_rtb_tag_key}"
    RT_TAG_VALUE="${var.pvt_rtb_tag_value}"

    yum install -y awscli iptables-services jq

    # Enable IPv4 and IPv6 forwarding
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf

    PRIMARY_IF=$(basename $(ls -1 /sys/class/net | grep -E 'eth0|ens|enp' | head -n1))

    # IPv4 NAT masquerading
    iptables -t nat -A POSTROUTING -o "$PRIMARY_IF" -j MASQUERADE
    service iptables save || true
    systemctl enable iptables

    # IPv6 NAT masquerading
    ip6tables -t nat -A POSTROUTING -o "$PRIMARY_IF" -j MASQUERADE
    service ip6tables save || true
    systemctl enable ip6tables

    # IMDSv2
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
      http://169.254.169.254/latest/meta-data/instance-id)

     ENI_ID=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --region "$REGION" \
      --query "Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId" \
      --output text)

    # Disable source/dest check on NAT instance
       aws ec2 modify-instance-attribute \
       --instance-id "$INSTANCE_ID" \
       --no-source-dest-check \
       --region "$REGION"


    AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
      http://169.254.169.254/latest/meta-data/placement/availability-zone)

    AZ_ID=$(echo "$AZ" | rev | cut -c1)

    # Create JSON filter file (CLOUD-INIT SAFE)
    cat > /tmp/filters.json << 'EOF2'
    [
      { "Name": "tag:Role", "Values": ["__RT_TAG_VALUE__"] },
      { "Name": "tag:AZ", "Values": ["__AZ_ID__"] }
    ]
    EOF2

    # Inject variables
    sed -i "s/__RT_TAG_VALUE__/$RT_TAG_VALUE/" /tmp/filters.json
    sed -i "s/__AZ_ID__/$AZ_ID/" /tmp/filters.json

    # Describe route tables using JSON filter file
    ROUTE_TABLES=$(aws ec2 describe-route-tables \
      --region "$REGION" \
      --filters file:///tmp/filters.json \
      --query "RouteTables[*].RouteTableId" \
      --output text)

    for RTB in $ROUTE_TABLES; do
      # IPv4 default route
      aws ec2 replace-route \
        --route-table-id "$RTB" \
        --destination-cidr-block "0.0.0.0/0" \
        --network-interface-id "$ENI_ID" \
        --region "$REGION" || \
      aws ec2 create-route \
        --route-table-id "$RTB" \
        --destination-cidr-block "0.0.0.0/0" \
        --network-interface-id "$ENI_ID" \
        --region "$REGION" || true

      # IPv6 default route
      aws ec2 replace-route \
        --route-table-id "$RTB" \
        --destination-ipv6-cidr-block "::/0" \
        --network-interface-id "$ENI_ID" \
        --region "$REGION" || \
      aws ec2 create-route \
        --route-table-id "$RTB" \
        --destination-ipv6-cidr-block "::/0" \
        --network-interface-id "$ENI_ID" \
        --region "$REGION" || true
    done
  EOF
}

