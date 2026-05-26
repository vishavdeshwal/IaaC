resource "aws_eip" "eip" {
    domain = "vpc"

    tags = {
        Name = "${var.environment}-${var.project}-nat-eip"
    }
}