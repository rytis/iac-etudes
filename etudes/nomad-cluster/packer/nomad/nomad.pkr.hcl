packer {
  required_plugins {
    amazon = {
      version = "~> 1.2"
      source = "github.com/hashicorp/amazon"
    }
  }
}

data "amazon-ami" "amazon_linux" {
  filters = {
    name = "amzn2-ami-hvm-*-x86_64-gp2"
    root-device-type = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners = ["amazon"]
}

source "amazon-ebs" "amazon_linux" {
  ami_name = "nomad-2023-07"
  instance_type = "t2.micro"
  region = "us-east-2"
  source_ami = data.amazon-ami.amazon_linux.id
  ssh_username = "ec2-user"
  force_deregister = true
  force_delete_snapshot = true
}

build {
  name = "nomad-build"
  sources = ["source.amazon-ebs.amazon_linux"]

  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/nomad.yml"
    user = "ec2-user"
    use_proxy = false
    ansible_env_vars = [
      "ANSIBLE_ROLES_PATH=../../ansible/roles"
    ]
  }
}
