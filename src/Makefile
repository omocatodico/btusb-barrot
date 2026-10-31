obj-m := btusb.o

KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=$(if $(shell grep -s '^CONFIG_CC_IS_CLANG=y' $(KDIR)/.config),1,) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
