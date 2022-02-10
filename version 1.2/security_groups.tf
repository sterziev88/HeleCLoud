############################################################
#######     Create Security Group as Bastion host    #######
############################################################

resource "aws_security_group" "bastion" {
  name        = "Bastion - SSH SG"
  description = "Allow SSH on port 22"
  vpc_id      = "${aws_vpc.test.id}"

  ingress {
    description      = "SSH Access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${var.ssh_access}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name            = "Bastion"
  }
}

################################################################
#######     Create Security Group for the Web Servers    #######
################################################################

resource "aws_security_group" "webserver_security_group" {
  name        = "Web Server Security Group"
  description = "Allow Web Traffic via LoadBalancer and SSH via Security Group"
  vpc_id      = "${aws_vpc.test.id}"

  ingress {
    description      = "Unsecure Web Traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.load_balancer_sg.id}"]
  }

  ingress {
    description      = "SSH Access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.bastion.id}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name            = "WebServer-SG"
  }
}

########################################################
#######     Create Security Group for the ALB    #######
########################################################

resource "aws_security_group" "load_balancer_sg" {
  name        = "Application Load Balancer Security Group"
  description = "Allow Web Traffic on Ports 80"
  vpc_id      = "${aws_vpc.test.id}"

  ingress {
    description      = "Unsecure Web Access (HTTP)"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name            = "Load-Balancer-SG"
  }
}


/*
############################################################
#######     Create Security Group for RDS Maria DB   #######
############################################################

resource "aws_security_group" "database_security_group" {
  name        = "Database Security Group"
  description = "Allow DB access on port 3306"
  vpc_id      = "${aws_vpc.test.id}"

  ingress {
    description      = ""
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.bastion.id}"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name            = "Database-Security-Group"
  }
}
*/