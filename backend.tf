terraform {
  backend "s3" {
    bucket       = "aabhinav-terraform-state-2026"
    key          = "terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
