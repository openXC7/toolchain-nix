.PHONY: run rebuild build clean

OWNER:=openxc7
CONTAINER:=$(OWNER)/toolchain-nix

run:
	podman run --rm -v $(PWD)/workspaces:/workspaces -it $(CONTAINER)

rebuild: clean build run

build:
	podman build -t $(CONTAINER) -f Containerfile

clean:
	podman rmi -f $(CONTAINER)
