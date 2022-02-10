
####################################
#######     Create a VPC     #######
####################################

resource "aws_vpc" "test" {
  cidr_block = "${var.vpc_cidr}"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "Test"
  }
}

####################################
#######     Create a IGW     #######
####################################

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id
  tags = {
    "Name" = "Test"
  }
}

########################################################
#######     Create public and private subnets    #######
########################################################

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnets_cidr)
  vpc_id            = "${aws_vpc.test.id}"
  cidr_block        = "${var.public_subnets_cidr[count.index]}"
  availability_zone = "${var.subnets_azs[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${format("Public-%d", count.index + 1)}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = "${aws_vpc.test.id}"
  cidr_block        = "${var.private_subnets_cidr[count.index]}"
  availability_zone = "${var.subnets_azs[count.index]}"

  tags = {
    Name = "${format("Private-%d", count.index + 1)}"
  }
}

###############################################################################
#######     Create a public Route table and two private Route tables    #######
#######    Associate public and private subnets with the Route tables   #######
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.test.id}"

route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }
  tags = {
    Name = "Public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.test.id}"
  count  = length(aws_subnet.private_subnets.*.id)

 #route {
 #   cidr_block      = "0.0.0.0/0"
 #   nat_gateway_id  = "${element(aws_nat_gateway.nat_gateways_test.*.id, count.index)}"
  #}

  tags = {
    Name = "${format("Private-%d", count.index + 1)}"
  }
}

resource "aws_route_table_association" "public" {
  count = "${length(var.public_subnets_cidr)}"

  subnet_id      = "${element(aws_subnet.public_subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  count = "${length(var.private_subnets_cidr)}"

  subnet_id      = "${element(aws_subnet.private_subnets.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

/*
##############################################################
#######     Create Elastic IPs for the NAT Gateways    #######
##############################################################

resource "aws_eip" "eip_ng" {
  vpc    = true
  count  = length(aws_subnet.public_subnets.*.id)

  tags   = {
    Name = "${format("eip_ng-%d", count.index + 1)}"
  }
}

##########################################
#######     Create NAT Gateways    #######
##########################################

resource "aws_nat_gateway" "nat_gateways_test" {

  # Allocating the Elastic IPs to the NAT Gateways!
  allocation_id = "${element(aws_eip.eip_ng.*.id, count.index)}"
  
  # Associating in the Public Subnets!
  subnet_id = "${element(aws_subnet.public_subnets.*.id, count.index)}"
  count = 2

  tags = {
    Name = "${format("Nat-gateway-%d", count.index + 1)}"
  }
}
*/

###########################################
#######     Create EC2 instances    #######
###########################################

resource "aws_key_pair" "ssh-key" {
   key_name          = "ssh-key"
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCidGutpH8D0Pg7mbtixoaY7EQwim2Z7kEUKoSV2w/028piXeJiEtYEBesuVD7bptdwCV65PKjw7iPxoe4gQvCJDQeXqydktYse1oybzEQrSH1c2uDAkaq5JHNWyCM1VkpppBVI1YEPJPDxz+4WddmRDE0JjpR9NMD9wJeLW0p9M3Tv/zqeFe9sh8F9gmt7HoKxd/arvY0CZ9tY3MqlQIcVqfl6k68bXXmI35El/F6c1qYqT2iFmho4QzrfAPHRRtsEJy8OcdOaAspPNed3Sd3BEva/bk4gv+MRGtrRLE2g7Y186e1hd+nTjjxv4uYQueMR85ZJOI4VRe4rIbeGyfaN imported-openssh-key"
 }


 resource "aws_instance" "ec2_instances" {
     count                   = length(aws_subnet.public_subnets.*.id)
     ami                     = "ami-04c921614424b07cd"
     instance_type           = "t2.micro"
     key_name                = aws_key_pair.ssh-key.id
     user_data               = "${file("./bootstrap.sh")}"
     subnet_id               = "${element(aws_subnet.public_subnets.*.id, count.index)}"
     vpc_security_group_ids  = [aws_security_group.webserver_security_group.id]

     tags = {
         Name = "${format("Webserver-%d", count.index + 1)}"
     }
 }

resource "aws_instance" "ec2_instances_private" {
     count                   = length(aws_subnet.private_subnets.*.id)
     ami                     = "ami-04c921614424b07cd"
     instance_type           = "t2.micro"
     key_name                = aws_key_pair.ssh-key.id
     user_data               = "${file("./bootstrap.sh")}"
     subnet_id               = "${element(aws_subnet.private_subnets.*.id, count.index)}"
     vpc_security_group_ids  = [aws_security_group.bastion.id]

     tags = {
         Name = "${format("Private-instance-%d", count.index + 1)}"
     }
 }
#######################################################
#######     Create Application Load Balancer    #######
#######     Create Target groups and listener   #######
#######################################################

resource "aws_lb" "test" {
  name               = "test"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  access_logs {
    bucket  = "${aws_s3_bucket.test-alb-log-terziev.id}"
    prefix  = "${aws_s3_bucket_object.alb-logs.id}"
    enabled = true
  } 
   tags = {
    Name = "ALB"
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name       = "alb-target-group"
  port       = 80
  protocol   = "HTTP"
  target_type = "instance"
  vpc_id     = "${aws_vpc.test.id}"

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-499"
  }
}

resource "aws_lb_target_group_attachment" "test" {
  count            = length(aws_instance.ec2_instances.*.id)
  target_group_arn = "${aws_lb_target_group.alb_target_group.arn}"
  target_id        = "${element(aws_instance.ec2_instances.*.id, count.index)}"
  port             = 80
}

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "s3_lb_write" {
  statement {
    principals {
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
      type = "AWS"
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.test-alb-log-terziev.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "load_balancer_access_logs_bucket_policy" {
  bucket = aws_s3_bucket.test-alb-log-terziev.id
  policy = data.aws_iam_policy_document.s3_lb_write.json
}


resource "aws_s3_bucket" "test-alb-log-terziev" {
  bucket = "test-alb-log-terziev"
  acl = "private"
  force_destroy = true

  #server_side_encryption_configuration {
  #  rule {
  #    apply_server_side_encryption_by_default {
  #      sse_algorithm = "AES256"
  #    }
  #  }
  #}
}


/*
resource "aws_s3_bucket_object" "alb-logs" {
    bucket = "${aws_s3_bucket.test-alb-log-terziev.id}"
    acl    = "private"
    key    = "alb-logs"
}
*/
/*
resource "aws_s3_bucket_policy" "test-alb-log-terziev" {
  bucket = aws_s3_bucket.test-alb-log-terziev.id

   policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::test-alb-log-terziev/alb-logs/*",
      "Principal": {
        "AWS": [
           "${data.aws_elb_service_account.main.arn}"
        ]
      }
    }
  ]
}
POLICY
}
*/

/*
####################################################
#######     Create Date Base subnet groups   #######
#######       Create RDS Maria Date Base     #######
####################################################

# Create Database Subnet Group
resource "aws_db_subnet_group" "db_subnets_group" {
  name         = "database_subnets"
  subnet_ids   = [for subnet in aws_subnet.private_subnets : subnet.id]

  tags   = {
    Name            = "DB-Subnet-Group"
  }
}

# Create Database Instance
resource "aws_db_instance" "database_instances" {
  identifier                = "mariadb"
  allocated_storage         = 20
  engine                    = "mariadb"
  engine_version            = "10.6.5"
  instance_class            = "db.t2.micro"
  name                      = "testdb"
  username                  = "sterzievdb"
  password                  = "sterzievdb"
  parameter_group_name      = "default.mariadb10.6"
  skip_final_snapshot       = true
  multi_az                  = true
  db_subnet_group_name      = aws_db_subnet_group.db_subnets_group.id
  vpc_security_group_ids    = [aws_security_group.database_security_group.id]

  tags = {
      Name = "RDS_MariaDB"
  }
}

output "database_Endpoint" {
  value = aws_db_instance.database_instances.endpoint
}
*/