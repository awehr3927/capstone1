locals {
  ssh_user = "ubuntu"
  private_key_path = "${path.module}/terraform_key"
  my_ami = "ami-0149b2da6ceec4bb0"
}


provider "aws" {
  region = "us-east-1"
  access_key = "OMITTED"
  secret_key = "OMITTED"
  token = "OMITTED"
}

resource "aws_key_pair" "login" {
  key_name = "login"
  public_key = file("${local.private_key_path}.pub")
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
}

resource "aws_internet_gateway" "maingw"{
    vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "mainrouting"{
    vpc_id = aws_vpc.main.id
    route{
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.maingw.id
    }
}

resource "aws_subnet" "main1"{
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "main2"{
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1b"
}

resource "aws_route_table_association" "public1"{
   subnet_id = aws_subnet.main1.id
   route_table_id = aws_route_table.mainrouting.id
}

resource "aws_route_table_association" "public2"{
   subnet_id = aws_subnet.main2.id
   route_table_id = aws_route_table.mainrouting.id
}

resource "aws_security_group" "projectaccess"{
  name = "projectnetrules"
  vpc_id = aws_vpc.main.id
  # allow all internal comms to be received
  # this allows alb/nlb/listener port address translation
  # this also allows k8s internode comms and service comms
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  # allow incoming kubectl
  ingress {
   from_port = 6443
   to_port = 6443
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }
  # allow incoming ssh
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allow incoming http
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allow incoming http api
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eip" "lbip" {
  vpc = true
  depends_on = [
     aws_internet_gateway.maingw
  ]
}

# Create Application Load Balancer
resource "aws_lb" "alb" {
    name               = "project-alb"
    internal           = true
    load_balancer_type = "application"
    security_groups    = [aws_security_group.projectaccess.id]
    subnets            = [aws_subnet.main1.id,aws_subnet.main2.id]
}

# Create ALB HTTP target group
resource "aws_lb_target_group" "a_http_tg" {
    #port     = 800
    port = 80
    protocol = "HTTP"
    target_type = "instance"
    vpc_id   = aws_vpc.main.id
    lifecycle{
      create_before_destroy = true
    }
}

# Create ALB API target group
resource "aws_lb_target_group" "a_api_tg" {
    #port     = 8800
    port = 8080
    protocol = "HTTP"
    target_type = "instance"
    vpc_id   = aws_vpc.main.id
    lifecycle{
      create_before_destroy = true
    }
}


# Attach compute instance master to http target group
resource "aws_lb_target_group_attachment" "masterto_a_http" {
  target_group_arn = aws_lb_target_group.a_http_tg.arn
  target_id = aws_instance.master.id
  port = 30400
    lifecycle{
      create_before_destroy = true
    }
}

# Attach compute instance worker1 to http target group
resource "aws_lb_target_group_attachment" "worker1to_a_http" {
  target_group_arn = aws_lb_target_group.a_http_tg.arn
  target_id = aws_instance.worker1.id
  port = 30400
    lifecycle{
      create_before_destroy = true
    }
}

# Attach compute instance worker2 to http target group
resource "aws_lb_target_group_attachment" "worker2to_a_http" {
  target_group_arn = aws_lb_target_group.a_http_tg.arn
  target_id = aws_instance.worker2.id
  port = 30400
    lifecycle{
      create_before_destroy = true
    }
}

# Attach compute instance master to api target group
resource "aws_lb_target_group_attachment" "masterto_a_api" {
  target_group_arn = aws_lb_target_group.a_api_tg.arn
  target_id = aws_instance.master.id
  port = 30800
    lifecycle{
      create_before_destroy = true
    }
}

# Attach compute instance worker1 to api target group
resource "aws_lb_target_group_attachment" "worker1to_a_api" {
  target_group_arn = aws_lb_target_group.a_api_tg.arn
  target_id = aws_instance.worker1.id
  port = 30800
    lifecycle{
      create_before_destroy = true
    }
}

# Attach compute instance worker2 to api target group
resource "aws_lb_target_group_attachment" "worker2to_a_api" {
  target_group_arn = aws_lb_target_group.a_api_tg.arn
  target_id = aws_instance.worker2.id
  port = 30800
    lifecycle{
      create_before_destroy = true
    }
}


# NLB:80 -> ALBListener:80 -> ALBTargetGroup:80 ->ALBTargetGroupAttachments for instances: 30400
resource "aws_lb_listener" "http" {
    # alb-http-listener
    load_balancer_arn = aws_lb.alb.arn
    port = aws_lb_target_group.a_http_tg.port
    protocol = "HTTP"
    default_action{
      type = "forward"
      target_group_arn = aws_lb_target_group.a_http_tg.arn
    }
    lifecycle{
      create_before_destroy = true
    }
}

# NLB:8080 -> ALBListener:8080 -> ALBTargetGroup:8080 ->ALBTargetGroupAttachments for instances: 30800
resource "aws_lb_listener" "api" {
    # alb-api-listener
    load_balancer_arn = aws_lb.alb.arn
    port = aws_lb_target_group.a_api_tg.port
    protocol = "HTTP"
    default_action{
      type = "forward"
      target_group_arn = aws_lb_target_group.a_api_tg.arn
    }
    lifecycle{
      create_before_destroy = true
    }
}


# Create NLB (ALB cannot bind to EIP, so we make an NLB to ALB)
resource "aws_lb" "nlb" {
    name               = "project-nlb"
    internal           = false
    load_balancer_type = "network"
    subnet_mapping {
      subnet_id = aws_subnet.main1.id
      allocation_id = aws_eip.lbip.id
    }
}


# Create NLB target group forwarding port 80 to ALB
resource "aws_lb_target_group" "n_http_tg" {
    port         = 80
    protocol     = "TCP"
    vpc_id       = aws_vpc.main.id
    target_type  = "alb"
    lifecycle{
      create_before_destroy = true
    }
}

# Create NLB target group forwarding port 8080 to ALB
resource "aws_lb_target_group" "n_api_tg" {
    port         = 8080
    protocol     = "TCP"
    vpc_id       = aws_vpc.main.id
    target_type  = "alb"
    lifecycle{
      create_before_destroy = true
    }
}

# Attach ALB to NLB's TCP 80 target group
resource "aws_lb_target_group_attachment" "albton_http_attachment" {
    # attach-alb-to-alb-to-nlb-targetgroup
    target_group_arn = aws_lb_target_group.n_http_tg.arn
    # attach the ALB to this target group
    target_id = aws_lb.alb.arn
    #  If the target type is alb, the targeted Application Load Balancer must have at least one listener whose port matches the target group port.
    # port must be alb listener port, we should target the varialbe to make sure it's active first
    port = aws_lb_listener.http.port
    lifecycle{
      create_before_destroy = true
    }
}

# Attach ALB to NLB's TCP 8080 target group
resource "aws_lb_target_group_attachment" "albton_api_attachment" {
    # attach-alb-to-alb-to-nlb-targetgroup
    target_group_arn = aws_lb_target_group.n_api_tg.arn
    # attach the ALB to this target group
    target_id = aws_lb.alb.arn
    #  If the target type is alb, the targeted Application Load Balancer must have at least one listener whose port matches the target group port.
    # port must be alb listener port, we should target the varialbe to make sure it's active first
    port = aws_lb_listener.api.port
    lifecycle{
      create_before_destroy = true
    }
}


# Create tcp listener on port 80 for NLB and point it to "NLB to ALB" target group
resource "aws_lb_listener" "tcp_http" {
    load_balancer_arn = aws_lb.nlb.arn
    port = aws_lb_target_group.n_http_tg.port
    protocol = "TCP"
    default_action{
      type = "forward"
      target_group_arn = aws_lb_target_group.n_http_tg.arn
    }
    lifecycle{
      create_before_destroy = true
    }
}

# Create tcp listener on port 8080 for NLB and point it to "NLB to ALB API" target group
resource "aws_lb_listener" "tcp_api" {
    load_balancer_arn = aws_lb.nlb.arn
    port = aws_lb_target_group.n_api_tg.port
    protocol = "TCP"
    default_action{
      type = "forward"
      target_group_arn = aws_lb_target_group.n_api_tg.arn
    }
    lifecycle{
      create_before_destroy = true
    }
}


resource "aws_instance" "master" {
  ami = local.my_ami
  instance_type = "t3.small"
  associate_public_ip_address = true
  subnet_id = aws_subnet.main1.id
  private_ip = "10.0.1.240"
  vpc_security_group_ids = [aws_security_group.projectaccess.id]
  key_name = aws_key_pair.login.key_name
 
  tags = {
    Name = "kubernetes-master"
  }

  connection {
    type = "ssh"
    host = self.public_ip
    user = local.ssh_user
    private_key  = file(local.private_key_path)
    timeout = "4m"
  }

  provisioner "remote-exec"{
    inline = [
      "echo 'foo'"
    ]
  }
  depends_on = [
     aws_internet_gateway.maingw
  ]

}

resource "aws_instance" "worker1" {
  ami = local.my_ami
  instance_type = "t3.small"
  associate_public_ip_address = true
  subnet_id = aws_subnet.main1.id
  vpc_security_group_ids = [aws_security_group.projectaccess.id]
  key_name = aws_key_pair.login.key_name

  tags = {
    Name = "kubernetes-worker1"
  }

  connection {
    type = "ssh"
    host = self.public_ip
    user = local.ssh_user
    private_key  = file(local.private_key_path)
    timeout = "4m"
  }

  provisioner "remote-exec"{
    inline = [
      "echo 'foo'",
    ]
  }
  depends_on = [
     aws_internet_gateway.maingw
  ]

}

resource "aws_instance" "worker2" {
  ami = local.my_ami
  instance_type = "t3.small"
  associate_public_ip_address = true
  subnet_id = aws_subnet.main2.id
  vpc_security_group_ids = [aws_security_group.projectaccess.id]
  key_name = aws_key_pair.login.key_name

  tags = {
    Name = "kubernetes-worker2"
  }

  connection {
    type = "ssh"
    host = self.public_ip
    user = local.ssh_user
    private_key  = file(local.private_key_path)
    timeout = "4m"
  }

  provisioner "remote-exec"{
    inline = [
      "echo 'foo'",
    ]
  }
  depends_on = [
     aws_internet_gateway.maingw
  ]

}

resource "null_resource" "configure_hosts" {
    provisioner "local-exec"{
      command = <<EOD
      cat <<EOF >sed.sh
cp ~/.kube/config /tmp/config
cat /tmp/config | grep -v certificate-authority-data | sed "s/10.0.1.240:6443/${aws_instance.master.public_ip}:6443\n    insecure-skip-tls-verify: true/g" > ~/.kube/config
rm -f /tmp/config
EOF
      cat <<EOF > myhosts
[masters]
${aws_instance.master.public_ip} ansible_user=${local.ssh_user} ansible_ssh_private_key_file=${local.private_key_path}
[workers]
${aws_instance.worker1.public_ip} ansible_user=${local.ssh_user} ansible_ssh_private_key_file=${local.private_key_path}
${aws_instance.worker2.public_ip} ansible_user=${local.ssh_user} ansible_ssh_private_key_file=${local.private_key_path}
EOF
      ansible-playbook -i myhosts deploy-kubernetes.yml
EOD
    }
}

resource "null_resource" "ready_kubernetes"{
    provisioner "local-exec"{
      command =  "ansible-playbook -i myhosts ready-kubernetes.yml"
    }
    depends_on = [
       null_resource.configure_hosts
    ]
}

resource "null_resource" "deploy_apps"{
    provisioner "local-exec"{
      command =  "./kube_deployment.sh"
    }
    depends_on = [
       null_resource.ready_kubernetes
    ]
}

resource "null_resource" "wait_for_webservices"{
    provisioner "local-exec"{
      command = "./wait_for_stable_webservice.sh ${aws_eip.lbip.public_ip}"
    }
    depends_on = [
       null_resource.deploy_apps
    ]
}

resource "null_resource" "load_data"{
    provisioner "local-exec"{
      command = <<EOD
for i in `seq 1 50`;
do
echo "curl ${aws_eip.lbip.public_ip}:8080/demo/add -d name=CUSTOMER$i -d transaction=$i.00"
curl ${aws_eip.lbip.public_ip}:8080/demo/add -d name=CUSTOMER$i -d transaction=$i.00
done
echo "wget -q -O- http://${aws_eip.lbip.public_ip}"
wget -q -O- http://${aws_eip.lbip.public_ip}
EOD
    }
    depends_on = [
       null_resource.wait_for_webservices
    ]

}

resource "null_resource" "load_test"{
    provisioner "local-exec"{
      command = "./load_test.sh"
    }
    depends_on = [
       null_resource.load_data
    ]
}

resource "null_resource" "load_and_test_pod_user"{
    provisioner "local-exec"{
      command = "./poduser_setup_and_test.sh" 
    }
    depends_on = [
       null_resource.load_test
    ]
}

resource "null_resource" "backup_etcd" {
   provisioner "local-exec"{
     command = "ansible-playbook -i myhosts backup-etcd.yml"
   }
   depends_on = [
      null_resource.load_and_test_pod_user
   ]
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}
output "master_ip" {
  value = aws_instance.master.public_ip
}
output "worker1_ip"{
  value = aws_instance.worker1.public_ip
}
output "worker2_ip"{
  value = aws_instance.worker2.public_ip
}
output "eip_ip"{
  value = aws_eip.lbip.public_ip
}

