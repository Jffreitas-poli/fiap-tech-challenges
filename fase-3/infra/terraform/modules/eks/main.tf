########################################################################
# modulo eks
# Cluster EKS + 1 managed node group. AMBOS usam a LabRole do AWS Academy
# (passada em var.lab_role_arn). O modulo NAO cria nenhuma IAM Role,
# Policy ou OIDC provider -- restricao do ambiente Vocareum.
########################################################################

locals {
  all_subnet_ids = concat(var.subnet_ids, var.public_subnet_ids)
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.lab_role_arn

  vpc_config {
    subnet_ids              = local.all_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = var.lab_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types
  ami_type        = var.node_ami_type
  disk_size       = var.node_disk_size

  scaling_config {
    min_size     = var.node_min
    desired_size = var.node_desired
    max_size     = var.node_max
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-ng" })

  # nodes precisam do access entry EC2_LINUX ja existente ao subir
  depends_on = [aws_eks_access_entry.node]

  # desired_size e gerenciado pelo Cluster Autoscaler/KEDA em runtime
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_addon" "this" {
  for_each = toset(var.cluster_addons)

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.default]
}

########################################################################
# EKS Access Entries (nao e IAM)
########################################################################

# Entry EC2_LINUX para a role dos nodes: sem isso, os nodes autenticam
# fora do grupo system:nodes, o EKS nao assina os CSRs kubelet-serving e
# metrics-server / kubectl top|logs|exec quebram com "tls: internal error".
resource "aws_eks_access_entry" "node" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.lab_role_arn
  type          = "EC2_LINUX"
}

# Admins humanos. A role dos nodes NUNCA entra aqui (colidiria com o
# entry EC2_LINUX acima -- um principal so pode ter um entry).
locals {
  admin_arns = toset([for a in var.admin_principal_arns : a if a != var.lab_role_arn])
}

resource "aws_eks_access_entry" "admins" {
  for_each = local.admin_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = local.admin_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}
