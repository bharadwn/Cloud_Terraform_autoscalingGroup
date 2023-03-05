# --------------------------------------------------------------------------------------------------------------------
# CONFIGURED Demo PROFILE (ALREADY) IN AWS CONFIGURE --PROFILE DEMO
# PROVIDER AND REGION SETTING
# --------------------------------------------------------------------------------------------------------------------
provider "aws" {
  profile = "demo"
  region  = "us-east-1"
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE VPC
# --------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "proj-VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "proj-VPC"
  }
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE SUBNET 1
# --------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "proj-Subnet1" {
  vpc_id            = aws_vpc.proj-VPC.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.1.0/24"
  # map_public_ip_on_launch = "false"
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE SUBNET 2
# --------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "proj-Subnet2" {
  vpc_id            = aws_vpc.proj-VPC.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.2.0/24"
  # map_public_ip_on_launch = "false"
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE ROUTE TABLE AND ASSOCIATIONS
# --------------------------------------------------------------------------------------------------------------------
resource "aws_route_table" "proj-RouteTable-Private" {
  vpc_id = aws_vpc.proj-VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "proj-associatedVPS" {
  subnet_id      = aws_subnet.proj-Subnet1.id
  route_table_id = aws_route_table.proj-RouteTable-Private.id
}

resource "aws_route_table_association" "proj-associatedVPS1" {
  subnet_id      = aws_subnet.proj-Subnet2.id
  route_table_id = aws_route_table.proj-RouteTable-Private.id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN APPLICATION LB TO ROUTE TRAFFIC ACROSS THE AUTO SCALING GROUP
# 2 AZs SET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "alb" {
  name               = "proj-asg-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2-sg.id]
  # availability_zones = ["${data.aws_availability_zones.all.names}"]
  subnets = [aws_subnet.proj-Subnet1.id, aws_subnet.proj-Subnet2.id]

  tags = {
    Environment = "${var.project}-lb-sg"
  }
}


# --------------------------------------------------------------------------------------------------------------------
# CREATE IGW
# --------------------------------------------------------------------------------------------------------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.proj-VPC.id

  tags = {
    Name = "proj-IGW"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP THAT CONTROLS WHAT TRAFFIC CAN GO IN AND OUT OF THE ALB AND EC2 INSTANCES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "ec2-sg" {
  name        = var.ec2-sg
  description = "Autoscaling project instance security group"
  vpc_id      = aws_vpc.proj-VPC.id

  ingress {
    from_port = var.Nginx_port
    to_port   = var.Nginx_port
    protocol  = "tcp"
    # cidr_blocks = [aws_default_vpc.default.cidr_block]
    # cidr_blocks = [aws_vpc.proj-VPC.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port = 0
    to_port   = 0
    # -1 is semantically equivalent to "all." So all protocols are allowed
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE ASG WITH 3,2,4 AS DESIRED, MIN AND MAX RESPECTIVELY
# --------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_group" "asg" {
  name                 = "web-asg"
  desired_capacity     = 3
  min_size             = 2
  max_size             = 4
  termination_policies = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.template.id
    version = "$Latest"
  }

  vpc_zone_identifier = [aws_subnet.proj-Subnet1.id, aws_subnet.proj-Subnet2.id]

  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  # wait_for_capacity_timeout = "3m"

  tag {
    key                 = "Name"
    value               = "asg-alb"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 85
    }
  }
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE SCALE UP DYNAMIC SCALING POLICY
# --------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "asg_policy_scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE CLOUDWATCH ALARM FOR SCALE UP
# --------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_description   = "Monitors CPU utilization for the ASG EC2s"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  alarm_name          = "proj_asg_scale_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "80"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE SCALE DOWN SCALING POLICY
# --------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "asg_policy_scale_down"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 200
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE CLOUDWATCH ALARM FOR SCALE DOWN
# --------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_description   = "Monitors CPU utilization for the ASG"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  alarm_name          = "proj_asg_scale_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "10"
  evaluation_periods  = "6"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE LAUNCH TEMPLATE FOR ASG/ EC2
# --------------------------------------------------------------------------------------------------------------------
#Subnet 2 instance resouce
resource "aws_launch_template" "template" {
  name          = "web-asg-template-1"
  instance_type = var.instance_type
  # image_id      = "ami-006dcf34c09e50022"
  # image_id = data.aws_ami.ami.id
  image_id = var.ami
  key_name = aws_key_pair.mykeypair.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2-sg.id]
    device_index                = "0"
    delete_on_termination       = "true"

  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.profile.arn
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name   = "Name"
      Source = "Autoscaling"
    }
  }
  user_data = filebase64("userData.sh")
}


# --------------------------------------------------------------------------------------------------------------------
# CREATE KEYPAIR
# --------------------------------------------------------------------------------------------------------------------
resource "aws_key_pair" "mykeypair" {
  key_name   = "mykeypair"
  public_key = file("${var.PATH_TO_PUBLIC_KEY}")
  # public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCTD2u7Tuc09e9GqutAd43HQUC8wIE8mHrVFOmg9Q69PjpTloSeRxThP+QgdeDcDuLSu9DNdZdU8NbvuHaV4Rthf09Tm9KkqLpYDrtqwp74ewb2pkXtUMnLreZcAFtNEiT9bONCZ40aK5wW2lUs65AUt1tdLVmDD0ZWj++2sBvyzNmLSXR/mGevQYquzVuWsVuyXm9eVx3KajbLuOHjA7dszGHDOC1sjM4nh9MOCSODGjLyk/DGOtu1msg3buBe0hnhs2nmw6lZQMWq6ctzzb74gjWZKJy7yXagASzVAzWCDbc7oIDXImfMl8yORijKJrKPUxmsQmSIw3jx9TlD2adl"
}


# --------------------------------------------------------------------------------------------------------------------
# CREATE IAM INSTANCE PROFILE
# --------------------------------------------------------------------------------------------------------------------
resource "aws_iam_instance_profile" "profile" {
  name = "project-lab-profile1"
  role = aws_iam_role.role.name
}

# --------------------------------------------------------------------------------------------------------------------
# CREATE IAM INSTANCE ROLE
# --------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "role" {
  name               = "project-lab-role"
  assume_role_policy = data.aws_iam_policy_document.assume_policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

