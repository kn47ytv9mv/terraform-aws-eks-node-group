variable "name" {
  default     = null
  description = "Name of the node group."
}

variable "cluster_name" {
  default     = null
  description = "Name of the EKS cluster the nodes join. Feed this from terraform-aws-eks-cluster's name output."
}

variable "node_role_arn" {
  default     = null
  description = "The ARN of the IAM role the nodes assume. Needs AmazonEKSWorkerNodePolicy, AmazonEC2ContainerRegistryReadOnly, and AmazonEKS_CNI_Policy unless the CNI runs under IRSA."
}

variable "subnet_ids" {
  default     = []
  description = "IDs of the subnets the nodes run in. Private subnets are the usual choice; nodes there still need a route out for image pulls."
}

variable "desired_size" {
  default     = 2
  description = "Number of nodes to run. If a cluster autoscaler or Karpenter manages this, expect it to drift from what Terraform recorded."
}

variable "min_size" {
  default     = 1
  description = "Minimum number of nodes."
}

variable "max_size" {
  default     = 3
  description = "Maximum number of nodes."
}

variable "instance_types" {
  default     = ["t3.medium"]
  description = "Instance types for the nodes. With capacity_type 'SPOT', list several so the group can fall back when one is unavailable."
}

variable "capacity_type" {
  default     = "ON_DEMAND"
  description = "Purchasing option for the nodes (e.g. 'ON_DEMAND' or 'SPOT'). 'SPOT' is substantially cheaper and can be reclaimed with two minutes' notice — see the README."
}

variable "ami_type" {
  default     = null
  description = "AMI family for the nodes (e.g. 'AL2023_x86_64_STANDARD', 'AL2023_ARM_64_STANDARD', or 'BOTTLEROCKET_x86_64'). Left null, AWS picks a default matching the instance types."
}

variable "disk_size" {
  default     = null
  description = "Root volume size in GiB. Cannot be set at the same time as launch_template — put the volume configuration in the template instead."
}

variable "max_unavailable" {
  default     = 1
  description = "How many nodes may be unavailable at once during a version update. Set max_unavailable_percentage instead for a proportion."
}

variable "max_unavailable_percentage" {
  default     = null
  description = "Percentage of nodes that may be unavailable at once during a version update. Mutually exclusive with max_unavailable; setting this takes precedence."
}

variable "labels" {
  default     = null
  description = "Kubernetes labels applied to the nodes."
}

variable "taints" {
  default     = []
  description = "Kubernetes taints applied to the nodes, used to keep general workloads off dedicated capacity."
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
}

variable "launch_template" {
  default     = null
  description = "An existing launch template to build the nodes from. Use this for custom AMIs, user data, or volume encryption. Mutually exclusive with disk_size."
  type = object({
    id      = optional(string)
    name    = optional(string)
    version = string
  })
}

variable "kubernetes_version" {
  default     = null
  description = "Kubernetes version for the nodes. Left null, the nodes follow the control plane's version."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the node group."
}
