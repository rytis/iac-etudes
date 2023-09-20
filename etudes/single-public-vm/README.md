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
