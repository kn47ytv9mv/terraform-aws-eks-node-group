# terraform-aws-eks-node-group

Terraform module for an EKS managed node group, the EC2 capacity a cluster
schedules pods onto. EKS manages the underlying autoscaling group, the AMI
and the draining behaviour during version updates; this module configures
it.

## Cost

The node group itself carries no charge. The nodes do, and they are the
bulk of what a Kubernetes cluster costs: EC2 instance hours plus an EBS
root volume per node, running continuously from the moment the group
exists.

The largest lever is `capacity_type = "SPOT"`, which costs a fraction of
on-demand. The trade is that AWS can reclaim an instance at short notice,
so it suits workloads that tolerate a node disappearing, and several
`instance_types` should be listed so the group has somewhere to fall back
to when one pool runs dry.

After that, right-size `instance_types` before adding more of them, and
set `desired_size` to what is actually needed rather than leaving headroom
running all month. Nodes in private subnets also pull images through a NAT
gateway, which is billed per gigabyte; that cost belongs to
`terraform-aws-vpc` but appears because of the nodes. Current rates are on
AWS's [EC2 pricing](https://aws.amazon.com/ec2/pricing/) page.

## Design

Defaults are two on-demand `t3.medium` nodes scaling between one and
three, replacing one node at a time during a version update. There is no
remote access block: nodes are given no SSH key, and the intended route in
is SSM Session Manager through the node role.

### Talking to the control plane

This needs no wiring. EKS attaches managed node groups to the cluster
security group it created for itself, so nodes reach the API server and
the control plane reaches the kubelet without any rule written here.
`terraform-aws-eks-cluster` exposes that group as
`cluster_security_group_id` for anything else that needs to pass through
it.

### Mutually exclusive arguments

`disk_size` and `launch_template` cannot both be set. An encrypted or
larger root volume belongs in the launch template, with `disk_size` left
null.

`max_unavailable` and `max_unavailable_percentage` are likewise exclusive.
This module drops the count form automatically when the percentage is set,
so either can be supplied without thinking about the other.

### Drift and prerequisites

`desired_size` drifts when a cluster autoscaler or Karpenter scales the
group, and the next apply pulls it back. Either let Terraform own the
number or ignore changes to it in the calling configuration.

Nodes in private subnets need a route out through a NAT gateway or VPC
endpoints, or image pulls fail in a way that resembles a cluster problem
rather than a networking one.

The node role needs `AmazonEKSWorkerNodePolicy`,
`AmazonEC2ContainerRegistryReadOnly` and `AmazonEKS_CNI_Policy` unless the
VPC CNI runs under IRSA. Build it with `terraform-aws-iam-role`.

## Usage

```hcl
module "nodes" {
  source = "kn47ytv9mv/eks-node-group/aws"

  name          = "example"
  cluster_name  = module.cluster.name
  node_role_arn = module.node_role.arn

  subnet_ids = module.private_subnets[*].id
}
```

Or directly from this repository:

```hcl
module "nodes" {
  source = "github.com/kn47ytv9mv/terraform-aws-eks-node-group"

  name          = "example"
  cluster_name  = module.cluster.name
  node_role_arn = module.node_role.arn

  subnet_ids = module.private_subnets[*].id
}
```

Spot capacity, tainted so only workloads that tolerate interruption land
on it:

```hcl
module "spot_nodes" {
  source = "kn47ytv9mv/eks-node-group/aws"

  name          = "example-spot"
  cluster_name  = module.cluster.name
  node_role_arn = module.node_role.arn

  subnet_ids = module.private_subnets[*].id

  capacity_type  = "SPOT"
  instance_types = ["t3.medium", "t3a.medium", "t2.medium"]

  desired_size = 3
  max_size     = 10

  taints = [
    { key = "spot", value = "true", effect = "PREFER_NO_SCHEDULE" }
  ]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the node group. | `null` | no |
| cluster_name | Name of the EKS cluster the nodes join. | `null` | no |
| node_role_arn | The ARN of the IAM role the nodes assume. | `null` | no |
| subnet_ids | IDs of the subnets the nodes run in. | `[]` | no |
| desired_size | Number of nodes to run. | `2` | no |
| min_size | Minimum number of nodes. | `1` | no |
| max_size | Maximum number of nodes. | `3` | no |
| instance_types | Instance types for the nodes. | `["t3.medium"]` | no |
| capacity_type | Purchasing option (e.g. `'ON_DEMAND'` or `'SPOT'`). | `"ON_DEMAND"` | no |
| ami_type | AMI family (e.g. `'AL2023_x86_64_STANDARD'`, `'BOTTLEROCKET_x86_64'`). | `null` | no |
| disk_size | Root volume size in GiB. Cannot be set alongside `launch_template`. | `null` | no |
| max_unavailable | How many nodes may be unavailable at once during a version update. | `1` | no |
| max_unavailable_percentage | Percentage of nodes that may be unavailable during an update. | `null` | no |
| labels | Kubernetes labels applied to the nodes. | `null` | no |
| taints | Kubernetes taints applied to the nodes. | `[]` | no |
| launch_template | An existing launch template to build the nodes from. | `null` | no |
| kubernetes_version | Kubernetes version for the nodes. Left null, they follow the control plane. | `null` | no |
| tags | A map of tags to assign to the node group. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the node group, in the form `cluster_name:node_group_name`. |
| arn | The ARN of the node group. |
| name | The name of the node group. |
| status | The status of the node group. |
| autoscaling_group_names | Names of the autoscaling groups EKS created behind the node group. |
| remote_access_security_group_id | The ID of the remote access security group, when there is one. |

## License

MIT — see [LICENSE.md](LICENSE.md).
