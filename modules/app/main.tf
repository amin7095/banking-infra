
resource "aws_security_group" "app" {
  name   = "${var.env_name}-app-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Allow ALB to App"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    description = "Allow outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data" {
  template = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-linux-extras aws-cli git

    # Clone app repo
    git clone ${var.app_repo} /opt/app

    # Install Datadog Agent
    DD_API_KEY=${var.datadog_api_key}
    DD_SITE=${var.datadog_site}
    DD_AGENT_MAJOR_VERSION=7
    bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

    # Install Gremlin Agent
    curl -s https://rpm.gremlin.com/gremlin.repo | tee /etc/yum.repos.d/gremlin.repo
    yum install -y gremlin gremlin-cli
    gremlin init --team-id "${var.gremlin_team_id}" --secret-key "${var.gremlin_secret}"

    # Pull test data from S3
    aws s3 cp s3://${var.test_data_bucket}/testdata.json /opt/app/testdata.json

    # Start Banking App
    cd /opt/app
    nohup java -jar banking-app.jar --server.port=8080 &
  EOF
}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.env_name}-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  user_data     = base64encode(data.template_file.user_data.rendered)
  iam_instance_profile {
    name = var.instance_profile_name
  }
  key_name = var.ssh_key_name
  security_group_names = [aws_security_group.app.name]
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.env_name}-asg"
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = var.private_subnets
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  target_group_arns = [var.target_group_arn]
}
