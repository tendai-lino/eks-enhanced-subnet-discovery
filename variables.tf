variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name" {
  type    = string
  default = "eks-demo"
}

# =========================================
# NAT66 Auto-Scaling Module - Variables
# =========================================

variable "nat66_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Optional: List of subnet IDs for NAT66 instances. If empty, subnets will be dynamically selected based on firewall=true tag"
}

variable "subnet_tag_key" {
  type        = string
  default     = "nat"
  description = "Tag key to identify subnets for NAT66 instances"
}

variable "subnet_tag_value" {
  type        = string
  default     = "true"
  description = "Tag value to identify subnets for NAT66 instances"
}

variable "name_prefix" {
  type        = string
  default     = "nat66"
  description = "Prefix for all resource names created by this module"
}



variable "nat_instance_type" {
  type        = string
  default     = "t4g.micro"
  description = "EC2 instance type for NAT66 instances (ARM-based recommended)"
}


variable "pvt_rtb_tag_key" {
  type        = string
  default     = "Role"
  description = "Tag key to identify Transit Gateway route tables"
}

variable "pvt_rtb_tag_value" {
  type        = string
  default     = "pvt-rtb"
  description = "Tag value to identify pvt route tables"
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Whether to assign a public IP address to NAT instances. Set to true if used for IPv4 NAT to internet. This allows the NAT instance to relay traffic via the Internet Gateway when IPv4 is in use."
}
# =========================================
# EKS Cluster Variables
# =========================================

variable "eks_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes version for EKS cluster"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.large"
  description = "EC2 instance type for EKS worker nodes"
}

variable "node_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of worker nodes per node group"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of worker nodes per node group"
}

variable "node_max_size" {
  type        = number
  default     = 3
  description = "Maximum number of worker nodes per node group"
}

variable "node_capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = "Capacity type for worker nodes (ON_DEMAND or SPOT)"
}
