variable "hadoop_master_instance_name" {
  description = "Value of the Name tag for the Hadoop Master EC2 instance"
  type        = string
  default     = "hadoop-master"
}

variable "hadoop_master_instance_count" {
  description = "Number of Hadoop Master EC2 instances to provision"
  type        = number
  default     = 1
}

variable "hadoop_worker_instance_name" {
  description = "Value of the Name tag for the Hadoop Worker EC2 instance"
  type        = string
  default     = "hadoop-worker"
}

variable "hadoop_worker_instance_count" {
  description = "Number of Hadoop Worker EC2 instances to provision"
  type        = number
  default     = 2
}

variable "private_key_path" {
  description = "Path to private key file"
  type        = string
  default     = "~/.ssh/aws_key"
}

variable "public_key_path" {
  description = "Path to private key file"
  type        = string
  default     = "~/.ssh/aws_key.pub"
}
