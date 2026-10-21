terraform {
  backend "s3" {
    bucket       = "projectbucket1-2026"
    key          = "terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
