#!/bin/sh

# Creates arena and its directory structure.
# Seeds arena with the sources from downloads/
# Post-processes them a bit (uses host sed, cp)

set -uex

[[ ! -e arena ]] || exit 1

# Create directory structure for the inputs
mkdir -p arena/seed/1/bin
mkdir -p arena/seed/1/src/{protomusl,tinycc,protobusybox}
mkdir -p arena/seed/2/src/gnumake
mkdir -p arena/seed/3/src

# Seed the only binary we need
[[ ! -e arena/tcc-seed ]] && cp tcc-seed arena/seed/1/bin/tcc

# Seed sources from downloads/
tar -C arena/seed/1/src/protomusl --strip-components=1 -xzf \
	downloads/musl-1.2.2.tar.gz
tar -C arena/seed/1/src/tinycc --strip-components=1 -xzf \
	downloads/tinycc-mob-git1645616.tar.gz
tar -C arena/seed/1/src/protobusybox --strip-components=1 -xjf \
	downloads/busybox-1.34.1.tar.bz2
tar -C arena/seed/2/src/gnumake --strip-components=1 -xzf \
	downloads/make-4.3.tar.gz
#tar -C arena/seed/?/src/linux --strip-components=1 -xJf \
#       downloads/linux-5.10.74.tar.xz

# Seed the bootstrap 'scripts'
cp stage1.c arena/seed/1/src/
cp stage2.sh arena/seed/2/src/
cp stage3.sh arena/seed/3/src/

# Seed extra sources from this repository
cp syscall.h arena/seed/1/src/  # dual-role
cp hello.c arena/seed/1/src/
cp protobusybox.[ch] arena/seed/1/src/


# Code host-processing hacks and workarounds, stage 1 only

pushd arena/seed/1/src/protomusl
	# original syscall_arch.h is not tcc-compatible,
	# the syscall.h we use is dual-role
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

pushd arena/seed/1/src/tinycc
	:> config.h
popd

pushd arena/seed/1/src/protobusybox
	:> include/NUM_APPLETS.h
	:> include/common_bufsiz.h
	# already fixed in an unreleased version
	sed -i 's/extern struct test_statics \*const test_ptr_to_statics/extern struct test_statics *BB_GLOBAL_CONST test_ptr_to_statics/' coreutils/test.c
popd
