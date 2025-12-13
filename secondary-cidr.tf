# -----------------------------
# Secondary CIDR Block
# -----------------------------
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "100.64.0.0/16"
}

# -----------------------------
# Secondary CIDR Subnets
# -----------------------------
resource "aws_subnet" "secondary_private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet("100.64.0.0/16", 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]

  tags = {
    Name = "${var.name}-secondary-private-${count.index + 1}"
    Tier = "secondary-private"
  }

  lifecycle {
    ignore_changes = [tags["kubernetes.io/role/cni"]]
  }
}

# -----------------------------
# Route Table Association for Secondary Subnets
# -----------------------------
resource "aws_route_table_association" "secondary_private" {
  count          = 2
  subnet_id      = aws_subnet.secondary_private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
