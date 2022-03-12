variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "EC2-Instance"
}

variable "instance_count" {
  description = "Number of EC2 instances to provision"
  type        = number
  default     = 4
}
