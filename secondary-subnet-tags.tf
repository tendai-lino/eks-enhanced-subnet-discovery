/* comment out last after secondary cidr for subnet discovery to kick in
# -----------------------------
# Tag Secondary Subnets for EKS CNI
# -----------------------------
resource "aws_ec2_tag" "secondary_subnet_cni" {
  count       = 2
  resource_id = aws_subnet.secondary_private[count.index].id
  key         = "kubernetes.io/role/cni"
  value       = "1"

  depends_on = [aws_subnet.secondary_private]
}
*/
