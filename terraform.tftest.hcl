mock_provider "aws" {}

variables {
  cluster_name  = "example"
  node_role_arn = "arn:aws:iam::123456789012:role/example"
  subnet_ids    = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

run "defaults_are_on_demand_and_small" {
  command = apply

  assert {
    condition     = aws_eks_node_group.resource.node_group_name == random_uuid.resource.id
    error_message = "With no name given, the node group should use the generated random_uuid."
  }

  assert {
    condition     = aws_eks_node_group.resource.capacity_type == "ON_DEMAND"
    error_message = "capacity_type should default to ON_DEMAND — spot reclamation should be opted into, not inherited."
  }

  assert {
    condition     = aws_eks_node_group.resource.instance_types == tolist(["t3.medium"])
    error_message = "instance_types should default to a single modest instance type."
  }

  assert {
    condition     = aws_eks_node_group.resource.scaling_config[0].desired_size == 2
    error_message = "desired_size should default to 2 so a single node loss is survivable."
  }

  assert {
    condition     = aws_eks_node_group.resource.scaling_config[0].min_size == 1 && aws_eks_node_group.resource.scaling_config[0].max_size == 3
    error_message = "min_size and max_size should default to 1 and 3."
  }

  assert {
    condition     = length(aws_eks_node_group.resource.taint) == 0
    error_message = "No taints should be applied by default."
  }

  assert {
    condition     = length(aws_eks_node_group.resource.launch_template) == 0
    error_message = "No launch_template block should be emitted when none is given."
  }
}

run "explicit_name_overrides_generated_uuid" {
  command = plan

  variables {
    name = "workers"
  }

  assert {
    condition     = aws_eks_node_group.resource.node_group_name == "workers"
    error_message = "An explicit name should be used instead of the generated UUID."
  }
}

run "update_config_uses_a_count_by_default" {
  command = plan

  assert {
    condition     = aws_eks_node_group.resource.update_config[0].max_unavailable == 1
    error_message = "max_unavailable should default to one node at a time."
  }

  assert {
    condition     = aws_eks_node_group.resource.update_config[0].max_unavailable_percentage == null
    error_message = "max_unavailable_percentage should be unset while the count form is in use — the provider rejects both together."
  }
}

run "percentage_replaces_the_count_when_given" {
  command = plan

  variables {
    max_unavailable_percentage = 25
  }

  assert {
    condition     = aws_eks_node_group.resource.update_config[0].max_unavailable_percentage == 25
    error_message = "max_unavailable_percentage should be passed through."
  }

  assert {
    condition     = aws_eks_node_group.resource.update_config[0].max_unavailable == null
    error_message = "max_unavailable must be dropped when the percentage form is used, or the provider rejects the pair."
  }
}

run "spot_capacity_with_several_instance_types" {
  command = plan

  variables {
    capacity_type  = "SPOT"
    instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
  }

  assert {
    condition     = aws_eks_node_group.resource.capacity_type == "SPOT"
    error_message = "capacity_type should be passed through."
  }

  assert {
    condition     = length(aws_eks_node_group.resource.instance_types) == 3
    error_message = "All instance types should be passed through so spot has fallbacks."
  }
}

run "taints_are_applied" {
  command = plan

  variables {
    taints = [
      { key = "dedicated", value = "gpu", effect = "NO_SCHEDULE" },
      { key = "spot", effect = "PREFER_NO_SCHEDULE" },
    ]
  }

  assert {
    condition     = length(aws_eks_node_group.resource.taint) == 2
    error_message = "Both taints should be applied to the node group."
  }
}

run "launch_template_is_passed_through" {
  command = plan

  variables {
    launch_template = {
      id      = "lt-00000000000000001"
      version = "$Latest"
    }
  }

  assert {
    condition     = length(aws_eks_node_group.resource.launch_template) == 1
    error_message = "A launch_template block should be emitted when one is given."
  }

  assert {
    condition     = aws_eks_node_group.resource.launch_template[0].version == "$Latest"
    error_message = "The launch template version should be passed through."
  }
}

run "node_version_can_be_pinned" {
  command = plan

  variables {
    kubernetes_version = "1.31"
  }

  assert {
    condition     = aws_eks_node_group.resource.version == "1.31"
    error_message = "An explicit kubernetes_version should pin the node version instead of following the control plane."
  }
}
