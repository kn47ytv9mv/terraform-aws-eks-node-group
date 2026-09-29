resource "random_uuid" "resource" {}

resource "aws_eks_node_group" "resource" {
  cluster_name    = var.cluster_name
  node_group_name = coalesce(var.name, random_uuid.resource.id)
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  ami_type       = var.ami_type
  disk_size      = var.disk_size
  version        = var.kubernetes_version

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable            = var.max_unavailable_percentage == null ? var.max_unavailable : null
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  dynamic "taint" {
    for_each = { for taint in var.taints : taint.key => taint }

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  dynamic "launch_template" {
    for_each = var.launch_template[*]

    content {
      id      = launch_template.value.id
      name    = launch_template.value.name
      version = launch_template.value.version
    }
  }

  labels = var.labels
  tags   = var.tags
}

output "id" {
  description = "The ID of the node group, in the form cluster_name:node_group_name."
  value       = aws_eks_node_group.resource.id
}

output "arn" {
  description = "The ARN of the node group."
  value       = aws_eks_node_group.resource.arn
}

output "name" {
  description = "The name of the node group."
  value       = aws_eks_node_group.resource.node_group_name
}

output "status" {
  description = "The status of the node group."
  value       = aws_eks_node_group.resource.status
}

output "autoscaling_group_names" {
  description = "Names of the autoscaling groups EKS created behind the node group. Useful for attaching scaling policies or finding the nodes in the console."
  value       = flatten([for resource in aws_eks_node_group.resource.resources : resource.autoscaling_groups[*].name])
}

output "remote_access_security_group_id" {
  description = "The ID of the security group EKS created for remote access to the nodes, when there is one."
  value       = try(aws_eks_node_group.resource.resources[0].remote_access_security_group_id, null)
}
