# Get the AZ in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to dynamically fetch AWS account ID
data "aws_caller_identity" "current" {}