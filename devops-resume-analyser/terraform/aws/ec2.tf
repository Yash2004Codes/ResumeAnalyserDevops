# Ubuntu 24.04 LTS (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Hop limit 2 lets containers reach IMDS, so boto3 can use the instance role
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size           = 30 # Free Tier covers 30 GB of EBS
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    tags = {
      Name = "resume-analyzer-root-vol"
    }
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url     = var.repo_url
    repo_branch  = var.repo_branch
    aws_region   = var.aws_region
    ecr_registry = local.ecr_registry
    s3_bucket    = aws_s3_bucket.resumes.bucket
  })

  tags = {
    Name = "resume-analyzer-server"
  }
}

# Static IP (free while attached to a running instance, within the Free Tier public-IPv4 hours)
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "resume-analyzer-eip"
  }
}
