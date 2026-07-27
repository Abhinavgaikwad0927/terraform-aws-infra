variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Image tag mutability"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scan on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type"
  type        = string
  default     = "AES256"
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy"
  type        = bool
  default     = true
}

variable "images_to_keep" {
  description = "Number of images to retain"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
