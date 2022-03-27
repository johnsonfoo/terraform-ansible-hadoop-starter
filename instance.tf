resource "aws_instance" "hadoop_master" {
  ami                    = var.ami
  instance_type          = var.instance_type
  count                  = var.hadoop_master_instance_count
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tags = {
    Name = var.hadoop_master_instance_name
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file(var.private_key_path)
  }

  # This is the Ansible playbook that configures Hadoop on the master and workers
  provisioner "file" {
    source      = "setup.yml"
    destination = "setup.yml"
  }

  provisioner "file" {
    source      = "teardown.yml"
    destination = "teardown.yml"
  }

  provisioner "file" {
    source      = "rack_topology.sh"
    destination = "rack_topology.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${self.tags.Name}"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo amazon-linux-extras install -y epel",
      # Install ansible on master
      "sudo amazon-linux-extras install -y ansible2",
      # Install ansible-galaxy on master
      "ansible-galaxy collection install community.general",
      # Keep ansible from verifying the identity of our workers
      "sudo sed -i.bak s/#host_key_checking/host_key_checking/ /etc/ansible/ansible.cfg",
      # Put the internal key we created on master and make sure we can connect to ourselves
      "echo -e \"${file(var.private_key_path)}\" > ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa",
      # Setup our /etc/hosts on master
      "echo \"${self.private_ip} ${self.tags.Name}\" | sudo tee -a /etc/hosts >/dev/null",
      "echo -e \"${local.worker_hosts}\" | sudo tee -a /etc/hosts >/dev/null",
      # Setup our /etc/ansible/hosts on master
      "echo -e \"${local.ansible_hosts}\" | sudo tee -a /etc/ansible/hosts >/dev/null",
      # Create temporary /home/ec2-user/workers on master
      "echo -e \"${local.workers}\" > ~/workers",
      # Create temporary /home/ec2-user/rack_topology.data on master
      "echo -e \"${local.rack_topology}\" > ~/rack_topology.data",
      # Run our playbook
      "ansible-playbook setup.yml"
    ]
  }
}

resource "aws_instance" "hadoop_worker" {
  ami                    = var.ami
  instance_type          = var.instance_type
  count                  = var.hadoop_worker_instance_count
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tags = {
    Name = "${var.hadoop_worker_instance_name}${count.index + 1}",
    Rack = count.index % 2 == 0 ? "/rack-01" : "/rack-02"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${self.tags.Name}"
    ]
  }
}