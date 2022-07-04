resource "aws_vpc" "main" {
    count       = "${var.vpc_count}"
    cidr_block  = "${element(var.cidr_prefix,count.index)}.0.0/16"
    tags        = merge(
    {
        "Name"  = "${element(var.vpc_name,count.index)}"
    })
}