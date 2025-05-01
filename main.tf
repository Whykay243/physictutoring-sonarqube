provider "aws" {
  profile = "Adeola"
  region = var.aws_region
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "whykay-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and HTTP access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow SSH access from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (restrict later!)
  }

  ingress {
    description = "Allow Jenkins access from anywhere"  
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  ingress {
    description = "Allow HTTPS access from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  # Add SonarQube port 9000
  ingress {
    description = "Allow SonarQube access from anywhere"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Allow HTTPS access from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name = "web-sg"  # Consistent with the name of the security group
  }
}

# use data source to get a registered ubuntu ami
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


# Create the EC2 instance for Jenkins and assign key pair

resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = "whykayKP"   # Use a single key
  associate_public_ip_address = true
  #availability_zone           = "us-east-1a"
  user_data                   = file("jenkinsinstall.sh")

  tags = {
    Name = "Jenkins_Server"
  }
}

# Tomcat Server
resource "aws_instance" "tomcat_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = "whykayKP"
  associate_public_ip_address = true
  #availability_zone           = "us-east-1b"
  user_data                   = file("installtomcat.sh")

  tags = {
    Name = "Tomcat_Server"
  }
}

# Sonaqube Server
resource "aws_instance" "sonaqube_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"          # upgraded from t2.micro
  subnet_id                   = module.vpc.public_subnets[2]
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = "whykayKP"
  associate_public_ip_address = true
  #availability_zone           = "us-east-1c"
  user_data                   = file("sonaqubeinstall.sh")

  tags = {
    Name = "sonaqube_Server"
  }
}


# Outputs
output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "tomcat_url" {
  description = "URL to access Tomcat"
  value       = "http://${aws_instance.tomcat_server.public_ip}:8080"
}

output "sonarqube_url" {
  description = "URL to access SonarQube"
  value       = "http://${aws_instance.sonarqube_server.public_ip}:9000"
}