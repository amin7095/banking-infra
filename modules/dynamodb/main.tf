resource "aws_dynamodb_table" "test" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "sample1" {
  table_name = aws_dynamodb_table.test.name
  hash_key   = aws_dynamodb_table.test.hash_key
  item = jsonencode({
    id         = { "S" = "cust-1001" }
    firstName  = { "S" = "Aisha" }
    kycStatus  = { "S" = "VERIFIED" }
    riskScore  = { "N" = "12" }
  })
}
