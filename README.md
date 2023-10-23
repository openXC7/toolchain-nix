## How to use

1. Install the nix package manager on your Linux distribution of choice (or use NixOS):
   See https://nixos.org/download.html :

```
$ sh <(curl -L https://nixos.org/nix/install) --daemon
```

2. Enable flakes:
Add the following to `~/.config/nix/nix.conf`  or `/etc/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

3. Then you will get a development shell with the complete toolchain with:
```
# nix develop github:openxc7/toolchain-nix
```