variable "aws_region" {
  type    = string
  default = "eu-south-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "project_name" {
  type    = string
  default = "selfhealing-monitoring"
}
