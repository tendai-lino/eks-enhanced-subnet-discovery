# EKS Enhanced Subnet Discovery Demo

This repository demonstrates EKS subnet discovery and secondary CIDR workflows for expanding pod IP capacity when the primary CIDR range is exhausted.

## Overview

This Terraform configuration creates a VPC infrastructure designed to showcase Amazon EKS's enhanced subnet discovery feature. The setup demonstrates how to dynamically expand available pod IPs by adding secondary CIDR blocks and leveraging EKS's automatic subnet detection.

## Architecture

- **Primary CIDR**: `192.168.200.0/24`
- **Secondary CIDR**: `100.64.0.0/16` (for pod IPs)
- **2 Availability Zones** with:
  - Public subnets (with NAT instances)
  - Private subnets (for EKS nodes)
  - Secondary private subnets (for additional pod IPs)

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
