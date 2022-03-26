locals {
  workers = join("\n", aws_instance.hadoop_worker[*].tags.Name)

  worker_hosts = templatefile(
    "template/worker_hosts.tftpl",
    {
      ip_name_pairs = zipmap(
        aws_instance.hadoop_worker[*].private_ip,
        aws_instance.hadoop_worker[*].tags.Name
      )
    }
  )

  ansible_hosts = templatefile(
    "template/ansible_hosts.tftpl",
    {
      names = aws_instance.hadoop_worker[*].tags.Name
    }
  )

  rack_topology = templatefile(
    "template/rack_topology.tftpl",
    {
      ip_rack_pairs = zipmap(
        aws_instance.hadoop_worker[*].private_ip,
        aws_instance.hadoop_worker[*].tags.Rack
      )
    }
  )
}