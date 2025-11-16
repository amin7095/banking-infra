
output "alb_dns"      { value = module.alb.alb_dns_name }
output "wiremock_url" { value = module.wiremock.internal_url }
output "db_endpoint"  { value = module.rds_mysql.endpoint }
