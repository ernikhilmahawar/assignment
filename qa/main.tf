## Creation of VPC with NAT/IG gateway

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"
  name    = "qa-test-vpc"
  cidr    = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  manage_default_security_group = true
  default_security_group_ingress = [
    {
      from_port   = 22,
      to_port     = 22,
      protocol    = "tcp",
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80,
      to_port     = 80,
      protocol    = "tcp",
      cidr_blocks = "10.0.101.0/24"
    }
  ]

  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Name = "qa-test-vpc"
  }
}


## Creation of EC2

module "ec2_cluster" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = "qa-test-server"
  instance_count = 2

  ami                    = "ami-0dc2d3e4c0f9ebd18" //hardcoded amazon linux2 ami under us-east-1 region
  instance_type          = "t2.micro"
  monitoring             = true
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids             = module.vpc.private_subnets
  user_data              = <<-EOF
                            #!/bin/bash
                            sudo su
                            yum -y install httpd
                            echo "<p> This is qa Environment! </p>" >> /var/www/html/index.html
                            sudo systemctl enable httpd
                            sudo systemctl start httpd
                            EOF

  tags = {
    Name = "qa-test"
  }
}

## Security group for ELB

resource "aws_security_group" "elb" {
  name        = "qa-test-elb-security-group"
  description = "To be used with qa-test-vpc"
  vpc_id      = module.vpc.vpc_id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


## Creation of ELB

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 3.0"

  name = "qa-test-elb"

  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.elb.id]
  internal        = false

  listener = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    }
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }


  // ELB attachments
  number_of_instances = 2
  instances           = module.ec2_cluster.id

  tags = {
    Name = "qa-test-elb"
  }
}
