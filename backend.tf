terraform {
  backend "s3" {
    bucket         = "abhinav-terraform-state-2026"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
