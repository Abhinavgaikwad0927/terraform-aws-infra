variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m7i-flex.large"
}
variable "ami_id" {
  description = "Amazon Linux 2 AMI"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair"
  type        = string
}
variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}
