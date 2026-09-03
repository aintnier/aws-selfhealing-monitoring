# ────────────────────────────────────────────────────────────────────
# Worker Node (Paziente) — Nginx + Redis + CloudWatch Agent + Chaos
# ────────────────────────────────────────────────────────────────────

resource "aws_security_group" "worker_sg" {
  name        = "${var.project_name}-worker-sg"
  description = "Security group for Worker Node (Patient)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP App"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Redis"
    from_port   = 6379
    to_port     = 6379
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

resource "aws_instance" "worker_node" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.worker_node_instance_type
  vpc_security_group_ids = [aws_security_group.worker_sg.id]
  key_name               = aws_key_pair.selfhealing_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  monitoring             = true

  tags = {
    Name = "${var.project_name}-worker-node"
  }

  user_data = <<-EOF
    #!/bin/bash
    # ── System ──
    dnf update -y
    dnf install -y docker git stress-ng

    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # ── Docker Compose ──
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # ── CloudWatch Agent (custom metrics: mem + disk) ──
    dnf install -y amazon-cloudwatch-agent

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCFG'
    {
      "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": ["disk_used_percent"],
            "resources": ["/"],
            "metrics_collection_interval": 60
          }
        },
        "append_dimensions": {
          "InstanceId": "$${aws:InstanceId}"
        }
      }
    }
    CWCFG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s

    # ── App Stack ──
    mkdir -p /opt/app
    cd /opt/app

    cat > index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head><title>Self-Healing Demo</title>
    <style>
      body { font-family: sans-serif; text-align: center; padding: 50px; background: #f0f2f5; }
      h1 { color: #1a73e8; }
      .status { font-size: 20px; color: green; }
    </style>
    </head>
    <body>
      <h1>Worker Node (Patient)</h1>
      <p class="status">System Operational (v2 Premium)</p>
      <p>Services: Nginx &bull; Redis</p>
    </body>
    </html>
    HTML

    cat > docker-compose.yml << 'EOC'
    version: "3.8"
    services:
      nginx:
        image: nginx:latest
        container_name: nginx
        ports:
          - "80:80"
        restart: unless-stopped
        volumes:
          - ./index.html:/usr/share/nginx/html/index.html

      redis:
        image: redis:alpine
        container_name: redis
        ports:
          - "6379:6379"
        restart: unless-stopped
    EOC


    /usr/local/bin/docker-compose up -d

    # ── Chaos Testing Scripts ──
    mkdir -p /opt/chaos

    cat > /opt/chaos/chaos-container-crash.sh << 'CHAOS1'
#!/bin/bash
echo "[CHAOS] Scenario 1: Application Crash"
echo "[CHAOS] Stopping Nginx container..."
docker stop nginx
echo "[CHAOS] Nginx container stopped."
    CHAOS1

    cat > /opt/chaos/chaos-cpu.sh << 'CHAOS2'
#!/bin/bash
DURATION=$${1:-300}
echo "[CHAOS] Scenario 2: CPU Overload for $${DURATION}s"
stress-ng --cpu 0 --timeout $${DURATION}s
echo "[CHAOS] CPU stress test completed."
    CHAOS2

    cat > /opt/chaos/chaos-memory.sh << 'CHAOS3'
#!/bin/bash
DURATION=$${1:-300}
echo "[CHAOS] Scenario 3: Memory Leak for $${DURATION}s"
TOTAL_MB=$(free -m | awk '/^Mem:/{print $$2}')
USED_MB=$(free -m | awk '/^Mem:/{print $$3}')
TARGET_MB=$$(( (TOTAL_MB * 88) / 100 ))
ALLOC_MB=$$(( TARGET_MB - USED_MB ))
echo "[CHAOS] Allocating $${ALLOC_MB}MB to reach exactly 88%..."
python3 -c "a = bytearray($${ALLOC_MB} * 1024 * 1024); import time; time.sleep($${DURATION})"
echo "[CHAOS] Memory stress test completed."
    CHAOS3

    cat > /opt/chaos/chaos-disk.sh << 'CHAOS4'
#!/bin/bash
echo "[CHAOS] Scenario 4: Disk Full"
TOTAL_KB=$(df / | tail -1 | awk '{print $$2}')
USED_KB=$(df / | tail -1 | awk '{print $$3}')
TARGET_KB=$(( (TOTAL_KB * 90) / 100 ))
FILL_KB=$(( TARGET_KB - USED_KB ))
FILL_MB=$(( FILL_KB / 1024 ))
echo "[CHAOS] Creating $${FILL_MB}MB bloat file..."
dd if=/dev/zero of=/opt/chaos/chaos-disk-bloat bs=1M count=$$FILL_MB status=progress 2>&1
echo "[CHAOS] Disk filled. Current usage:"
df -h /
    CHAOS4

    chmod +x /opt/chaos/*.sh
  EOF

  lifecycle {
    ignore_changes = [user_data]
  }
}
