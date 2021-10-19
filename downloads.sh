#!/bin/sh
set -uex

mkdir -p downloads
cd downloads
[[ -e va_list.c ]] ||
	wget https://repo.or.cz/tinycc.git/blob_plain/ca11849ebb88ef4ff87beda46bf5687e22949bd6:/lib/va_list.c
[[ -e musl-1.2.2.tar.gz ]] ||
	wget http://musl.libc.org/releases/musl-1.2.2.tar.gz
[[ -e make-4.3.tar.gz ]] ||
	wget http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
[[ -e busybox-1.34.1.tar.bz2 ]] ||
	wget https://busybox.net/downloads/busybox-1.34.1.tar.bz2
[[ -e linux-5.10.74.tar.xz ]] ||
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.74.tar.xz

sha256sum -c <<EOF
d647913c5c4a4146b3a760b30e293baa428a580cb387e2014bcf749666e1f644  va_list.c
9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd  musl-1.2.2.tar.gz
e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19  make-4.3.tar.gz
415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549  busybox-1.34.1.tar.bz2
5755a6487018399812238205aba73a2693b0f9f3cd73d7cf1ce4d5436c3de1b0  linux-5.10.74.tar.xz
EOF
