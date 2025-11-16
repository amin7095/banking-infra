
resource "aws_security_group_rule" "alb_to_app" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  security_group_id        = var.app_sg_id
  source_security_group_id = var.alb_sg_id
}
