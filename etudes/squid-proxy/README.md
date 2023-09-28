- Deploy single VM
- Public network
- Access configuration
  - SSH access for management
  - Configurable inbound ports
  - Console access
- Customised image
  - Preinstalled packages
  - Preconfigured
- Postbuild configuration

# Usage

## Build image

In `packer/` run:

```
$ packer init build.pkr.hcl
$ packer build build.pkr.hcl
```

### Test build playbook

When developing playbooks it might be quicker to iterate and test changes
on the same instance of target machine.

Start packer build in debug mode:

```
$ packer build -debug build.pkr.hcl
```

Wait for initial provisioner run, which will stop and wait for your input with the following:

```
Pausing after run of step 'StepProvision'. Press enter to continue.
```

While the Packer is waiting for input, copy and paste the ansible command it ran (will be shown)
in to another terminal window, prepend/append the following to it, and then run:

```
$ ANSIBLE_ROLES_PATH=../../ansible/roles \
  <...long ansible-playbook command from packer output...> \
  -i '<ip of the temp instance as shown in packer output>,' -u ec2-user
```

If you need to access the temporary instance, run the following:

```
$ ssh uc2-user@<ip of the temp instance as shown in packer output> -i ec2_squid-proxy.pem
```

## Deploy everything

In `terraform/`:

```
$ terraform init
$ terraform apply
```

# Tips

## Access EC2 instance that is not on public network

Set up [port forwarding](https://aws.amazon.com/blogs/aws/new-port-forwarding-using-aws-system-manager-sessions-manager/) to the instance.

## SSM on CLI

Install AWS CLI [SSM plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

```
$ aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId,State.Name]"
$ aws ssm start-session --target <...instance-id...>
```
