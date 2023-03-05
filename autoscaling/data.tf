# data "aws_ami" "ami" {
#   most_recent = true
#   owners      = ["amazon", "self"]

#   filter {
#     name = "name"
#     # values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
#     values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
#   }
# }


data "aws_ami" "proj_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {}

# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners =["099720109477"]
#   filter {
#     name="name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
#   }
# }

data "aws_iam_policy_document" "assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}
