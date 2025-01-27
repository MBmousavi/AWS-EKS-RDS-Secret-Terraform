variable "region" {
  description = "region"
  type        = string
}

variable "profile" {
  type        = string
  description = "AWS Profile"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}