
# NAT66 Auto-Scaling Module - Data Sources
# =========================================

# Pull the correct ARM64 AL2023 AMI from SSM - Includes amazon-ssm-agent preinstalled
data "aws_ssm_parameter" "al2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}


# Convert SSM value to a real AMI (optional but recommended)
data "aws_ami" "amazon_linux_latest_arm" {
  owners = ["137112412989"] # Amazon

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.al2023_arm.value]
  }
}

# Dynamically fetch subnets with specified tags (default: firewall=true)
data "aws_subnets" "nat66_subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.this.id]
  }

  tags = {
    "${var.subnet_tag_key}" = var.subnet_tag_value
  }
}

data "aws_subnet" "nat66_subnet_details" {
  for_each = toset(data.aws_subnets.nat66_subnets.ids)
  id       = each.value
}
