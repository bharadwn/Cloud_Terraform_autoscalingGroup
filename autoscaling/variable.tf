variable "ami" {
  type    = string
  default = "ami-006dcf34c09e50022"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for launch template"
  default     = "t2.micro"
}

variable "project" {
  default = "AutoscalingNGINXProject"
}

variable "PATH_TO_PUBLIC_KEY" {
  description = "Public key file to create the key pair"
  default     = "new1.pub"
}

variable "ec2-sg" {
  default = "ssh-nginx-sg"
}

variable "Nginx_port" {
  type        = string
  description = "Nginx port"
  default     = "80"
}
