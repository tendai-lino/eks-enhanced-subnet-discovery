#   Comment out block after first code run 
# =========================================
# EKS Cluster Configuration
# =========================================

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "${var.name}-cluster"
  }
}

# =========================================
# EKS Add-ons
# =========================================

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "vpc-cni"
  addon_version            = "v1.20.4-eksbuild.2"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = null

  depends_on = [
    aws_eks_node_group.this
  ]

  tags = {
    Name = "${var.name}-vpc-cni"
  }
}

# Pod Identity Agent Add-on
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "eks-pod-identity-agent"
  addon_version     = "v1.3.10-eksbuild.1"
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.this
  ]

  tags = {
    Name = "${var.name}-pod-identity-agent"
  }
}

# =========================================
# EKS Node Group Configuration
# =========================================

# Node Group IAM Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS Node Group - One per AZ
resource "aws_eks_node_group" "this" {
  count           = 2
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-node-group-${count.index == 0 ? "a" : "b"}"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private[count.index].id]

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = [var.node_instance_type]
  capacity_type  = var.node_capacity_type

  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = var.name
    AZ          = count.index == 0 ? "a" : "b"
  }

  tags = {
    Name = "${var.name}-node-group-${count.index == 0 ? "a" : "b"}"
    AZ   = count.index == 0 ? "a" : "b"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]
}
