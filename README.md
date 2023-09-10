# Infrastructure-as-Code Études

## Pre-requisites

Install the following locally:
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [Terrform](https://developer.hashicorp.com/terraform/downloads)
- [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Set up AWS account and CLI, so that it is [SSO authenticated](https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html). Make sure you can run without errors:
- `aws sso login`
- `aws s3 ls`
