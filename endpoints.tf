# S3 Gateway Endpoint for private subnets (no hourly charge)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to the private route table so private subnets reach S3 without NAT
  route_table_ids = [aws_route_table.private_rt.id]

  tags = { Name = "s3-endpoint" }
}