# =========================================
# NAT66 Auto-Scaling Module - Main Resources
# =========================================

# IAM Role and Policies
resource "aws_iam_role" "nat66_role" {
  name = "${var.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "nat66_policy" {
  name = "${var.name_prefix}-policy"
  role = aws_iam_role.nat66_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRouteTables",
          "ec2:ReplaceRoute",
          "ec2:CreateRoute",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ec2:ModifyInstanceAttribute"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "nat66_ssm_core" {
  role       = aws_iam_role.nat66_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat66_profile" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.nat66_role.name
}

# Security Group
resource "aws_security_group" "nat66_sg" {
  name   = "${var.name_prefix}-sg"
  vpc_id = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow all IPv4 inbound (stateful return traffic)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow all IPv6 inbound (stateful return traffic)"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

# Launch Template
resource "aws_launch_template" "nat66_lt" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_latest_arm.id
  instance_type = var.nat_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.nat66_profile.name
  }

  network_interfaces {
    associate_public_ip_address = var.assign_public_ip
    security_groups             = [aws_security_group.nat66_sg.id]
    delete_on_termination       = true
  }

  user_data = base64encode(local.nat66_user_data)

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Groups - One per AZ in public subnets
resource "aws_autoscaling_group" "nat66_asg" {
  count = 2

  name             = "${var.name_prefix}-az${count.index + 1}-asg"
  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  vpc_zone_identifier = [aws_subnet.public[count.index].id]

  launch_template {
    id      = aws_launch_template.nat66_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 40

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-nat66-az${count.index + 1}"
    propagate_at_launch = true
  }
}
