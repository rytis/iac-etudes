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
in to another terminal window, append the following to it, and then run:

```
$ <..long ansible-playbook command..> -i '<ip of the temp instance>,' -u ec2-user
```

