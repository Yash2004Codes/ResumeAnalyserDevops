# Only HTTP is exposed. Shell access is via SSM Session Manager (no SSH port).
resource "aws_security_group" "app_sg" {
  name        = "resume-analyzer-sg"
  description = "HTTP-only ingress for the Resume Analyzer host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP (nginx)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound (Groq API, ECR, SSM, package mirrors)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "resume-analyzer-sg"
  }
}
