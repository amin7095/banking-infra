
output "alb_dns_name"     { value = aws_lb.this.dns_name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "sg_id"            { value = aws_security_group.alb.id }
