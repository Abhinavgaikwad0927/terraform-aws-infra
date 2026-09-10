variable "instance_type" {
  default = "m7i-flex.large"
}
variable "iam_instance_profile" {
  description = "IAM instance profile attached to EC2"
  type        = string
}
variable "ami_id" {}
variable "subnet_id" {}
variable "security_group_id" {}
