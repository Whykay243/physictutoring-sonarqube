variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}
variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "whykayKP"
}
