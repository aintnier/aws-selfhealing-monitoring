provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for self-healing EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP app (nginx)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "n8n"
    from_port   = 5678
    to_port     = 5678
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_key_pair" "selfhealing_key" {
  key_name   = "selfhealing-key"
  public_key = file("${path.module}/../../../.ssh/selfhealing-key.pub")
}


resource "aws_instance" "monitoring_ec2" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.selfhealing_key.key_name

  tags = {
    Name = "${var.project_name}-ec2"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    mkdir -p /opt/stack
    cd /opt/stack

    cat > docker-compose.yml << 'EOC'
    version: "3.8"
    services:
      n8n:
        image: n8nio/n8n:latest
        ports:
          - "5678:5678"
        environment:
          - N8N_BASIC_AUTH_ACTIVE=false
          - N8N_HOST=localhost
          - N8N_SECURE_COOKIE=false
        volumes:
          - n8n_data:/home/node/.n8n

      grafana:
        image: grafana/grafana-oss:latest
        ports:
          - "3000:3000"
        volumes:
          - grafana_data:/var/lib/grafana

      app:
        image: nginx:alpine
        ports:
          - "80:80"

    volumes:
      n8n_data:
      grafana_data:
    EOC

    /usr/local/bin/docker-compose up -d
  EOF
}

resource "aws_eip" "monitoring_eip" {
  instance = aws_instance.monitoring_ec2.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}
