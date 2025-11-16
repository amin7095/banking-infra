
# Key pair
resource "aws_key_pair" "this" {
  key_name   = "${var.name}-kp"
  public_key = var.ssh_public_key
}

# AMI lookup (Amazon Linux 2023)
data "aws_ami" "al2023" {
  owners      = ["137112412989"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }
}

# App SG (no direct ingress; Alb->App rule created separately)
resource "aws_security_group" "app" {
  name   = "${var.name}-app-sg"
  vpc_id = var.vpc_id
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.this.key_name

  user_data = base64encode(var.user_data)

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "${var.name}-asg"
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [var.alb_tg_arn]
  tag { key = "Name" value = "${var.name}-app" propagate_at_launch = true }
}
