variable "server_port" {
  description = "Port 8080"
  type        = number
  default     = 8080
}

variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 isntance type"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}
variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state"
  type        = string
}

variable "db_remote_state_key" {
  description = "The path for the database's remote state in S3"
  type        = string
}

variable "custom_tags" {
  description = "Custom tags for ASG instances"
  type = map(string)
  default = {}
}