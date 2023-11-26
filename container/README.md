# Toolchain container for openXC7 FPGA Development

## How to use locally
Please [install podman](https://podman.io/) on your machine.
Podman is supported in Windows, MacOS and Linux and is free & open source.

Run the following command once to build the local container image:
```shell
# Build development environment container ...
make build

# .. and run it
make run
```

### Example usage ###
To run the development environment locally and compile blinky (see [screen recording](https://youtu.be/3cs_hfdYNE4)):
```shell
# Whenever you want to compile your project, enter the virtual machine
make run
# ...or to avoid using make:
podman run --rm -v $PWD/workspaces:/workspaces -it openxc7/toolchain-nix

# In the running container now
git clone https://github.com/openXC7/demo-projects
cd demo-projects/blinky-qmtech
make
exit

# Back at your host machine you can now see the compiled bitstream
ls -l workspaces/demo-projects/blinky-qmtech/blinky.bit
```
