

data "aws_ami" "latest-ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



module "jumphost" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = format("%s-demo-jumphost-%s", var.prefix, random_id.id.hex)
  instance_count = 1

  ami                         = data.aws_ami.latest-ubuntu.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = var.ec2_key_name
  monitoring                  = true
  vpc_security_group_ids      = [module.bigip_mgmt_sg.this_security_group_id]
  subnet_ids                  = module.vpc.public_subnets

  # this box needs to know the ip address of the bigip and the juicebox host
  # it also needs to know the bigip username and password to use

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Application = var.prefix
  }
}