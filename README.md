![eks-secret](https://github.com/user-attachments/assets/c1987248-a258-484a-922c-f0bafe0f1489)

For setting up the infra on AWS, I used Terraform and S3/DynamoDB as remote backend. After initing the process and migratong the local remote state file to the S3, We can proceed to apply every directory.

Every component uses a unique state file:
```
S3 Backend     => global/s3/terraform.tfstate
VPC            => global/vpc/terraform.tfstate
secret manager => global/secret/terraform.tfstate
RDS            => global/rds/terraform.tfstate
EKS            => global/eks/terraform.tfstate
```

For every directory to apply I use this for example:
```
cd 1-vpc/
terraform apply -var-file ../terraform.tfvars
```

After setting up the whole stack, we should see that the secret file and secrets envs are added to the EKS deployment. We can test it by getting a bash of the pod and run env command and checking the mounted secret directory:



<img width="497" alt="Screenshot 2025-01-27 at 21 19 26" src="https://github.com/user-attachments/assets/a0acf7b7-06d6-4587-be71-5dee2cb29cb2" />
