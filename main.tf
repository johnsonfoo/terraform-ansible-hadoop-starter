terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.5"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "ap-southeast-1"
}

resource "aws_instance" "hadoop_master_ec2_instance" {
  ami                    = "ami-02f47fa62c613afb4"
  instance_type          = "t2.micro"
  count                  = var.hadoop_master_instance_count
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tags = {
    Name = "${var.hadoop_master_instance_name}"
  }
}

resource "aws_instance" "hadoop_worker_ec2_instance" {
  ami                    = "ami-02f47fa62c613afb4"
  instance_type          = "t2.micro"
  count                  = var.hadoop_worker_instance_count
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tags = {
    Name = "${var.hadoop_worker_instance_name}${count.index + 1}"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = file("${var.public_key_path}")
}

resource "aws_security_group" "ec2_security_group" {
  ingress = [
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "NameNode WebUI"
      from_port        = 50070
      to_port          = 50070
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "NameNode Metadata Service"
      from_port        = 9000
      to_port          = 9000
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "DataNode WebUI"
      from_port        = 50075
      to_port          = 50075
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress {
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "null_resource" "hadoop_master_ec2_instance" {
  count = var.hadoop_master_instance_count

  triggers = {
    cluster_instance_ids = aws_instance.hadoop_master_ec2_instance.*.id[count.index]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = aws_instance.hadoop_master_ec2_instance.*.public_ip[count.index]
    private_key = file("${var.private_key_path}")
  }

  # Install java and xmlstarlet
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install java-1.8.0-openjdk-devel",
      "sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm",
      "sudo yum -y install xmlstarlet"
    ]
  }

  # Download hadoop
  provisioner "remote-exec" {
    inline = [
      "wget https://archive.apache.org/dist/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz",
      "sudo tar xvzf hadoop-* -C /usr/local",
      "rm hadoop-*",
      "sudo mv /usr/local/hadoop-* /usr/local/hadoop"
    ]
  }

  # Add java and hadoop environment variables
  provisioner "remote-exec" {
    inline = [
      "echo 'export JAVA_HOME=$(readlink -f /usr/bin/java | sed \"s:/bin/java::\")' >> .bashrc",
      "echo 'export PATH=$PATH:$JAVA_HOME/bin' >> .bashrc",
      "echo 'export HADOOP_HOME=/usr/local/hadoop' >> .bashrc",
      "echo 'export PATH=$PATH:$HADOOP_HOME/bin' >> .bashrc",
      "echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' >> .bashrc",
      "source ~/.bashrc"
    ]
  }

  # Update both namenode and datanode common conf files
  provisioner "remote-exec" {
    inline = [
      "cd $HADOOP_CONF_DIR",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v fs.defaultFS -s /configuration/property -t elem -n value -v hdfs://${aws_instance.hadoop_master_ec2_instance[0].private_dns}:9000 core-site.xml",
      "sudo xmlstarlet ed -L core-site.xml",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v yarn.nodemanager.aux-services -s /configuration/property -t elem -n value -v mapreduce_shuffle -s /configuration -t elem -n property -s /configuration/property[2] -t elem -n name -v yarn.resourcemanager.hostname -s /configuration/property[2] -t elem -n value -v ${aws_instance.hadoop_master_ec2_instance[0].private_dns} yarn-site.xml",
      "sudo xmlstarlet ed -L yarn-site.xml",
      "sudo cp mapred-site.xml.template mapred-site.xml",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v mapreduce.jobtracker.address -s /configuration/property -t elem -n value -v ${aws_instance.hadoop_master_ec2_instance[0].private_dns}:54311 -s /configuration -t elem -n property -s /configuration/property[2] -t elem -n name -v mapreduce.framework.name -s /configuration/property[2] -t elem -n value -v yarn mapred-site.xml",
      "sudo xmlstarlet ed -L mapred-site.xml"
    ]
  }

  # Update ssh files
  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -f ~/.ssh/id_rsa -t rsa -P \"\"",
      "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys",
      "echo \"Host namenode\n    HostName ${aws_instance.hadoop_master_ec2_instance[0].private_dns}\n    User ec2-user\n    IdentityFile ~/.ssh/id_rsa\" >> ~/.ssh/config",
      "worker_private_dns_list=(${join(" ", aws_instance.hadoop_worker_ec2_instance[*].private_dns)})",
      "for i in $${!worker_private_dns_list[@]}; do echo \"Host datanode$((i+1))\n    HostName $${worker_private_dns_list[$i]}\n    User ec2-user\n    IdentityFile ~/.ssh/id_rsa\" >> ~/.ssh/config; done",
      "ssh-keyscan -H ${aws_instance.hadoop_master_ec2_instance[0].private_dns} >> ~/.ssh/known_hosts",
      "ssh-keyscan -H 0.0.0.0 >> ~/.ssh/known_hosts",
      "for i in $${!worker_private_dns_list[@]}; do ssh-keyscan -H $${worker_private_dns_list[$i]} >> ~/.ssh/known_hosts; done",
      "chmod 600 ~/.ssh/config"
    ]
  }

  # Update namenode specific conf files
  provisioner "remote-exec" {
    inline = [
      "cd $HADOOP_CONF_DIR",
      "sudo rm /etc/hosts",
      "echo ${aws_instance.hadoop_master_ec2_instance[0].private_ip} ${aws_instance.hadoop_master_ec2_instance[0].private_dns} | sudo tee -a /etc/hosts",
      "worker_private_ip_list=(${join(" ", aws_instance.hadoop_worker_ec2_instance[*].private_ip)})",
      "worker_private_dns_list=(${join(" ", aws_instance.hadoop_worker_ec2_instance[*].private_dns)})",
      "for i in $${!worker_private_ip_list[@]}; do echo $${worker_private_ip_list[$i]} $${worker_private_dns_list[$i]} | sudo tee -a /etc/hosts; done",
      "echo \"127.0.0.1 localhost\" | sudo tee -a /etc/hosts",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v dfs.replication -s /configuration/property -t elem -n value -v 3 -s /configuration -t elem -n property -s /configuration/property[2] -t elem -n name -v dfs.namenode.name.dir -s /configuration/property[2] -t elem -n value -v file:///usr/local/hadoop/data/hdfs/namenode hdfs-site.xml",
      "sudo xmlstarlet ed -L hdfs-site.xml",
      "sudo mkdir -p $HADOOP_HOME/data/hdfs/namenode",
      "sudo touch masters",
      "echo ${aws_instance.hadoop_master_ec2_instance[0].private_dns} | sudo tee -a masters",
      "sudo rm slaves",
      "for i in $${!worker_private_dns_list[@]}; do echo $${worker_private_dns_list[$i]} | sudo tee -a slaves; done",
      "sudo chown -R ec2-user $HADOOP_HOME"
    ]
  }
}

resource "null_resource" "hadoop_worker_ec2_instance" {
  count = var.hadoop_worker_instance_count

  triggers = {
    cluster_instance_ids = aws_instance.hadoop_worker_ec2_instance.*.id[count.index]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = aws_instance.hadoop_worker_ec2_instance.*.public_ip[count.index]
    private_key = file("${var.private_key_path}")
  }

  # Install java and xmlstarlet
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install java-1.8.0-openjdk-devel",
      "sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm",
      "sudo yum -y install xmlstarlet"
    ]
  }

  # Download hadoop
  provisioner "remote-exec" {
    inline = [
      "wget https://archive.apache.org/dist/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz",
      "sudo tar xvzf hadoop-* -C /usr/local",
      "rm hadoop-*",
      "sudo mv /usr/local/hadoop-* /usr/local/hadoop"
    ]
  }

  # Add java and hadoop environment variables
  provisioner "remote-exec" {
    inline = [
      "echo 'export JAVA_HOME=$(readlink -f /usr/bin/java | sed \"s:/bin/java::\")' >> .bashrc",
      "echo 'export PATH=$PATH:$JAVA_HOME/bin' >> .bashrc",
      "echo 'export HADOOP_HOME=/usr/local/hadoop' >> .bashrc",
      "echo 'export PATH=$PATH:$HADOOP_HOME/bin' >> .bashrc",
      "echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' >> .bashrc",
      "source ~/.bashrc"
    ]
  }

  # Update both namenode and datanode common conf files
  provisioner "remote-exec" {
    inline = [
      "cd $HADOOP_CONF_DIR",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v fs.defaultFS -s /configuration/property -t elem -n value -v hdfs://${aws_instance.hadoop_master_ec2_instance[0].private_dns}:9000 core-site.xml",
      "sudo xmlstarlet ed -L core-site.xml",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v yarn.nodemanager.aux-services -s /configuration/property -t elem -n value -v mapreduce_shuffle -s /configuration -t elem -n property -s /configuration/property[2] -t elem -n name -v yarn.resourcemanager.hostname -s /configuration/property[2] -t elem -n value -v ${aws_instance.hadoop_master_ec2_instance[0].private_dns} yarn-site.xml",
      "sudo xmlstarlet ed -L yarn-site.xml",
      "sudo cp mapred-site.xml.template mapred-site.xml",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v mapreduce.jobtracker.address -s /configuration/property -t elem -n value -v ${aws_instance.hadoop_master_ec2_instance[0].private_dns}:54311 -s /configuration -t elem -n property -s /configuration/property[2] -t elem -n name -v mapreduce.framework.name -s /configuration/property[2] -t elem -n value -v yarn mapred-site.xml",
      "sudo xmlstarlet ed -L mapred-site.xml",
    ]
  }

  # Update datanode specific conf files
  provisioner "remote-exec" {
    inline = [
      "cd $HADOOP_CONF_DIR",
      "sudo xmlstarlet ed -L -s /configuration -t elem -n property -s /configuration/property -t elem -n name -v dfs.replication -s /configuration/property -t elem -n value -v 3 -s /configuration -t elem -n property -s /configuration/property[2] -t elem -n name -v dfs.datanode.data.dir -s /configuration/property[2] -t elem -n value -v file:///usr/local/hadoop/data/hdfs/datanode hdfs-site.xml",
      "sudo xmlstarlet ed -L hdfs-site.xml",
      "sudo mkdir -p $HADOOP_HOME/data/hdfs/datanode",
      "sudo chown -R ec2-user $HADOOP_HOME"
    ]
  }
}
