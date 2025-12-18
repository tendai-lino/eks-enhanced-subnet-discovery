# EKS Enhanced Subnet Discovery Demo

[![Terraform](https://img.shields.io/badge/Terraform-1.4+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-VPC%20%7C%20EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Author**: Tendai Musonza  
> A production-ready demonstration of Amazon EKS subnet discovery and secondary CIDR workflows for dynamically expanding pod IP capacity.

This repository demonstrates EKS subnet discovery and secondary CIDR workflows for expanding pod IP capacity when the primary CIDR range is exhausted.

## 🎥 Video Demo

This project is demonstrated step-by-step in the following video:

👉 https://www.youtube.com/watch?v=ZC3U6sADp_o

The video walks through:
- **EKS enhanced subnet discovery** for dynamically expanding pod IP capacity
- Pod IP allocation behaviour in the VPC (VPC CNI)
- IP exhaustion using a deliberately small primary CIDR
- Expanding pod IP capacity using a secondary CIDR
- Subnet tagging required for enhanced subnet discovery


## Overview

This Terraform configuration creates a VPC infrastructure designed to showcase Amazon EKS's enhanced subnet discovery feature. The setup demonstrates how to dynamically expand available pod IPs by adding secondary CIDR blocks and leveraging EKS's automatic subnet detection.

## Architecture

- **Primary CIDR**: `192.168.200.0/24`
- **Secondary CIDR**: `100.64.0.0/16` (for pod IPs)
- **2 Availability Zones** with:
  - Public subnets (with NAT instances)
  - Private subnets (for EKS nodes)
  - Secondary private subnets (for additional pod IPs)

### Network Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          VPC: 192.168.200.0/24                              │
│                     Secondary CIDR: 100.64.0.0/16                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌────────────────────────────────┬────────────────────────────────┐       │
│  │    Availability Zone A         │    Availability Zone B         │       │
│  │                                │                                │       │
│  │  ┌──────────────────────────┐  │  ┌──────────────────────────┐  │       │
│  │  │  Public Subnet           │  │  │  Public Subnet           │  │       │
│  │  │  192.168.200.0/27        │  │  │  192.168.200.32/27       │  │       │
│  │  │  Tags: nat=true, AZ=a    │  │  │  Tags: nat=true, AZ=b    │  │       │
│  │  │                          │  │  │                          │  │       │
│  │  │  ┌────────────────────┐  │  │  │  ┌────────────────────┐  │  │       │
│  │  │  │  NAT Instance      │  │  │  │  │  NAT Instance      │  │  │       │
│  │  │  │  (Auto Scaling)    │──┼──┼──┼──│  (Auto Scaling)    │──┼──┼──┐    │
│  │  │  │  Public IP         │  │  │  │  │  Public IP         │  │  │  │    │
│  │  │  └────────────────────┘  │  │  │  └────────────────────┘  │  │  │    │
│  │  └──────────────────────────┘  │  └──────────────────────────┘  │  │    │
│  │              │                  │              │                  │  │    │
│  │              │ Internet         │              │ Internet         │  │    │
│  │              │ Gateway          │              │ Gateway          │  │    │
│  │              ▼                  │              ▼                  │  │    │
│  │  ════════════════════════════  │  ════════════════════════════  │  │    │
│  │              ▲                  │              ▲                  │  │    │
│  │              │                  │              │                  │  │    │
│  │  ┌──────────────────────────┐  │  ┌──────────────────────────┐  │  │    │
│  │  │  Private Subnet          │  │  │  Private Subnet          │  │  │    │
│  │  │  192.168.200.64/27       │  │  │  192.168.200.96/27       │  │  │    │
│  │  │  (EKS Worker Nodes)      │  │  │  (EKS Worker Nodes)      │  │  │    │
│  │  │                          │  │  │                          │  │  │    │
│  │  │  Route Table (AZ-a)      │  │  │  Route Table (AZ-b)      │  │  │    │
│  │  │  Role=pvt-rtb, AZ=a   ───┼──┼──┼──│  Role=pvt-rtb, AZ=b   ───┼──┼──┘    │
│  │  │  0.0.0.0/0 → NAT-a       │  │  │  0.0.0.0/0 → NAT-b       │  │       │
│  │  └──────────────────────────┘  │  └──────────────────────────┘  │       │
│  │              │                  │              │                  │       │
│  │              │                  │              │                  │       │
│  │  ┌──────────────────────────┐  │  ┌──────────────────────────┐  │       │
│  │  │  Secondary Private       │  │  │  Secondary Private       │  │       │
│  │  │  100.64.0.0/24           │  │  │  100.64.1.0/24           │  │       │
│  │  │  (Pod IPs)               │  │  │  (Pod IPs)               │  │       │
│  │  │                          │  │  │                          │  │       │
│  │  │  Tags:                   │  │  │  Tags:                   │  │       │
│  │  │  kubernetes.io/role/cni=1│  │  │  kubernetes.io/role/cni=1│  │       │
│  │  │  Tier=secondary-private  │  │  │  Tier=secondary-private  │  │       │
│  │  └──────────────────────────┘  │  └──────────────────────────┘  │       │
│  │                                │                                │       │
│  └────────────────────────────────┴────────────────────────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Traffic Flow:
  ═══════  Internet Gateway (bidirectional)
  ────▶    NAT Instance route (private → internet)
  
EKS Pod IP Allocation:
  • Primary subnets: Worker node IPs from 192.168.200.0/24
  • Secondary subnets: Pod IPs from 100.64.0.0/16 (via CNI subnet discovery)
```

## Deployment Workflow

### Step 1: Deploy VPC Infrastructure

Deploy the base VPC with primary CIDR, subnets, and NAT instances:

```bash
terraform init
terraform apply
```

This creates:
- VPC with primary CIDR block
- 2 public subnets (for NAT instances and ALB)
- 2 private subnets (for EKS worker nodes)
- Internet Gateway
- Per-AZ private route tables
- Auto-scaling NAT instances with high availability

### Step 2: Deploy EKS Cluster

Create your EKS cluster using the private subnets for node groups:

```bash
# Use the private subnet IDs from Terraform outputs
# Deploy EKS cluster in the private subnets
```

### Step 3: Monitor Pod IP Exhaustion

As your workloads grow, monitor pod IP usage:

```bash
# Check available IPs in subnets
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, podCIDR: .spec.podCIDR}'
```

### Step 4: Add Secondary CIDR Block

When approaching pod IP limits, the secondary CIDR and subnets are already provisioned with the initial deployment. The secondary subnets include:
- `100.64.0.0/24` in AZ-a
- `100.64.1.0/24` in AZ-b

### Step 5: Enable Subnet Discovery

Tag the secondary subnets to trigger EKS subnet discovery:

```bash
# Apply the CNI tag to secondary subnets
terraform apply -target=aws_ec2_tag.secondary_subnet_cni
```

Or manually tag in AWS Console:
- Key: `kubernetes.io/role/cni`
- Value: `1`

EKS VPC CNI will automatically discover these subnets and allocate pod IPs from the secondary CIDR range.

## Key Features

### NAT Instance High Availability
- Auto-scaling groups ensure NAT instances are automatically replaced if they fail
- Instances run user data scripts that dynamically update route tables
- Per-AZ route tables with AZ-specific tagging for proper routing

### Dynamic Subnet Discovery
- Secondary subnets use lifecycle rules to ignore CNI tag changes
- Tags are managed separately from subnet resources for flexibility
- EKS automatically detects tagged subnets without cluster restart

### Modular Design
- Separate `.tf` files for logical grouping
- Variables for easy customization
- Outputs for integration with EKS deployment

## Files Structure

```
├── vpc.tf                    # VPC, IGW, primary subnets, route tables
├── secondary-cidr.tf         # Secondary CIDR block and subnets
├── secondary-subnet-tags.tf  # CNI tags for subnet discovery
├── launch.tf                 # NAT instance ASG, IAM roles, security groups
├── user_data.tf              # NAT instance bootstrap script
├── data.tf                   # Data sources for AMIs and subnet queries
├── variables.tf              # Input variables
├── outputs.tf                # Output values
└── README.md                 # This file
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `region` | `eu-west-1` | AWS region |
| `name` | `eks-demo` | Resource name prefix |
| `subnet_tag_key` | `nat` | Tag key for NAT subnet selection |
| `subnet_tag_value` | `true` | Tag value for NAT subnet selection |
| `pvt_rtb_tag_key` | `Role` | Tag key for private route tables |
| `pvt_rtb_tag_value` | `pvt-rtb` | Tag value for private route tables |
| `nat_instance_type` | `t4g.micro` | NAT instance type |
| `assign_public_ip` | `true` | Assign public IP to NAT instances |

## Outputs

Use these outputs when creating your EKS cluster:

- `vpc_id` - VPC ID
- `private_subnet_ids` - Primary private subnet IDs (for EKS nodes)
- `secondary_subnet_ids` - Secondary private subnet IDs (for pod IPs)
- `public_subnet_ids` - Public subnet IDs (for load balancers)

## Prerequisites

- Terraform >= 1.4.0
- AWS CLI configured with appropriate credentials
- Permissions to create VPC, EC2, IAM resources

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

**Note**: Ensure your EKS cluster is deleted before destroying the VPC infrastructure.

## References

- [EKS Custom Networking](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html)
- [EKS VPC CNI Configuration](https://github.com/aws/amazon-vpc-cni-k8s)
- [Secondary CIDR Blocks](https://docs.aws.amazon.com/vpc/latest/userguide/configure-your-vpc.html#add-cidr-block-restrictions)

---

## Author

**Tendai Musonza**

[![GitHub](https://img.shields.io/badge/GitHub-tendai--lino-181717?logo=github)](https://github.com/tendai-lino)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?logo=linkedin)](https://linkedin.com/in/tendai-musonza-a9914523)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/tendai-lino/eks-enhanced-subnet-discovery/issues).

---

⭐ If you find this project helpful, please consider giving it a star!
