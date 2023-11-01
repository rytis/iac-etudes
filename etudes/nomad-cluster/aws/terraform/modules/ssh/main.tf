resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "nomad" {
  key_name = "nomad"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_sensitive_file" "nomad_ssh_key" {
  content = "${tls_private_key.ssh_key.private_key_openssh}"
  filename = "${path.module}/nomad_ssh.key"
}
