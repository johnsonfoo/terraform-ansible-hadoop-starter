data "aws_eip" "hadoop_master_elastic_ip" {
  public_ip = "3.1.36.136"
}

resource "aws_eip_association" "hadoop_master_eip_association" {
  instance_id   = aws_instance.hadoop_master[0].id
  allocation_id = data.aws_eip.hadoop_master_elastic_ip.id
}
