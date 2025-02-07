# egp-agent

[EMETH GPU POOL](https://gpupool.ai) Agent Program for Hosting.

## Requirements

- Ubuntu 22.04 LTS
- Enable Virtualization in BIOS
- Enable sudo access
- Storage: 500GB or more
- KVM
- Vagrant
- Not GPU Geforce Seriese
  > Due to NVIDIA's license policy, hosting with Geforce series GPUs is prohibited. Please choose an appropriate GPU.

## Install

```sh
curl -sOL https://raw.githubusercontent.com/alt-develop/egp-agent/main/install.sh
sh install.sh
```

> Important: 
> If you're planning to list a machine that's part of a Private Network, it's necessary to route it through our Forwarder Server. Should you decide to proceed, we can supply the required SSH Key for the setup. Please don't hesitate to reach out to us for this or any other queries.
> Contact us at: <https://gpupool.ai/user/contact-us>


## Uninstall

```sh
curl -sOL https://raw.githubusercontent.com/alt-develop/egp-agent/main/uninstall.sh
sh uninstall.sh
```
