#!/bin/sh

# Creates arena and its directory structure.
# Seeds arena with the sources from downloads/
# Post-processes them a bit (uses host sed, cp)

set -uex

[[ ! -e arena ]] || exit 1

# Create directory structure for the inputs
mkdir -p arena/seed/{bin,src}
mkdir -p arena/seed/src/{protomusl,sash,make,busybox,linux}
# Create basic directory structure for the outputs
mkdir -p arena/stage/1/{src,obj,lib,bin}

# Seed the only binary we need
[[ ! -e arena/tcc-seed ]] && cp tcc-seed arena/seed/bin/tcc

# Seed sources from downloads/
tar -C arena/seed/src/protomusl --strip-components=1 -xzf \
	downloads/musl-1.2.2.tar.gz
tar -C arena/seed/src/sash --strip-components=1 -xzf \
	downloads/sash-3.8.tar.gz
tar -C arena/seed/src/make --strip-components=1 -xzf \
	downloads/make-4.3.tar.gz
tar -C arena/seed/src/busybox --strip-components=1 -xjf \
	downloads/busybox-1.34.1.tar.bz2
#tar -C arena/seed/src/linux --strip-components=1 -xJf \
#       downloads/linux-5.10.74.tar.xz

# Seed the bootstrap 'script'
cp stage1.c arena/seed/src/

# Seed extra sources from this repository
cp downloads/{libtcc1.c,va_list.c,alloca.S} arena/seed/src/
cp syscall.h arena/seed/src/  # dual-role
cp hello.c arena/seed/src/


# Create per-component output directory structure

mkdir -p arena/stage/1/obj/protomusl/crt
mkdir -p arena/stage/1/obj/protomusl/setjmp/x86_64
mkdir arena/stage/1/obj/sash


# Code host-processing hacks and workarounds

pushd arena/seed/src/protomusl
	# original syscall.h is not tcc-compatible, the one we use is dual-role
	cp ../syscall.h arch/x86_64/syscall_arch.h

	# three files have to be generated with host sed
	mkdir -p stage0-generated/{sed1,sed2,cp}/bits

	sed -f ./tools/mkalltypes.sed \
		./arch/x86_64/bits/alltypes.h.in \
		./include/alltypes.h.in \
		> stage0-generated/sed1/bits/alltypes.h

	cp arch/x86_64/bits/syscall.h.in stage0-generated/cp/bits/syscall.h

	sed -n -e s/__NR_/SYS_/p \
		< arch/x86_64/bits/syscall.h.in \
		>> stage0-generated/sed2/bits/syscall.h

	echo '#define VERSION "1.2.2"' > src/internal/version.h

	sed -i 's/@PLT//' src/signal/x86_64/sigsetjmp.s

	rm src/signal/restore.c  # *BIG URGH*

	rm src/thread/__set_thread_area.c  # possible double-define
	rm src/thread/__unmapself.c  # double-define
	rm src/math/sqrtl.c  # tcc-incompatible
	rm src/math/{acoshl,acosl,asinhl,asinl,hypotl}.c  # want sqrtl
popd

pushd arena/seed/src/sash
	sed -i 's|#include <linux/loop.h>||' cmds.c
popd
