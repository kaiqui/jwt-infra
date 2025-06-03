terraform {
  backend "s3" {
    bucket = "jwt-bucket-terraform-state"
    key    = "jwt-infra/terraform.tfstate"
    region = "sa-east-1"
  }
}
