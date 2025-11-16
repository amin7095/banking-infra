
resource "aws_security_group" "wiremock" {
  name        = "${var.name}-wiremock-sg"
  description = "WireMock"
  vpc_id      = var.vpc_id

  ingress {
    from_port                = 8080
    to_port                  = 8080
    protocol                 = "tcp"
    security_groups          = [var.app_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "al2023" {
  owners      = ["137112412989"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }
}



locals {
  mapping_write = join("\n", [
    for k, v in var.mappings : <<-EOT
cat > /home/wiremock/mappings/${k} <<'JSON'
${v}
JSON
EOT
  ])
}


resource "aws_instance" "wiremock" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.wiremock.id]

  user_data = <<BASH
#!/bin/bash
set -eux
yum update -y
yum install -y docker
systemctl enable --now docker
mkdir -p /home/wiremock/mappings /home/wiremock/__files
${local.mapping_write}
# Run WireMock
/usr/bin/docker run -d --name wiremock   -p 8080:8080   -v /home/wiremock:/home/wiremock   --restart always   wiremock/wiremock:latest
BASH

  tags = { Name = "${var.name}-wiremock" }
}

output "internal_url" { value = "http://wiremock.internal:8080" }
