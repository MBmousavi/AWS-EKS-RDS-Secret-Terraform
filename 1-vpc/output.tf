output "vpc_id" {
  value = module.vpc.vpc_id
}
output "private_subnets" {
  value = module.vpc.private_subnets
}
output "public_subnets" {
  value = module.vpc.public_subnets
}
output "intra_subnets" {
  value = module.vpc.intra_subnets
}
output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}
output "database_subnet_group" {
  value = module.vpc.database_subnet_group
}