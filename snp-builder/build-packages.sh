#!/bin/bash

set -e

ROOT_DIR=$(realpath .)
SCRIPT_DIR=$ROOT_DIR/snp-builder
BUILD_DIR=$ROOT_DIR/build

#If set to 1, use our forks for OVMF, QEMU and Linux kernel
USE_STABLE_SNAPSHOT=0

usage() {
  echo "$0 [options]"
  echo " -amdsev <path to dir>                   Use local AMDSEV repository (e.g., for incremental builds)"
  echo " -use-stable-snapshots               	 If set, use our stable snapshots of the kernel, OVMF, and QEMU repos. We experienced frequent errors with AMD's upstream repos."
  exit
}

while [ -n "$1" ]; do
	case "$1" in
		-amdsev) AMDPATH="$2"
			shift
			;;
		-use-stable-snapshots) USE_STABLE_SNAPSHOT=1
			;;
		*)
			usage
			;;
	esac

	shift
done

mkdir -p $BUILD_DIR

echo "Installing build dependencies for kernel, OVMF and QEMU"
sudo apt update
xargs -a $SCRIPT_DIR/dependencies.txt sudo apt install -y --no-install-recommends

echo "Installing libslirp 4.7.1 packages, needed to enable user networking in QEMU"
wget http://se.archive.ubuntu.com/ubuntu/pool/main/libs/libslirp/libslirp0_4.7.0-1_amd64.deb -O libslirp0.deb
wget http://se.archive.ubuntu.com/ubuntu/pool/main/libs/libslirp/libslirp-dev_4.7.0-1_amd64.deb -O libslirp-dev.deb

sudo dpkg -i libslirp0.deb
sudo dpkg -i libslirp-dev.deb

rm -rf libslirp0.deb libslirp-dev.deb

if [ -z "$AMDPATH" ]; then
	AMDPATH=$BUILD_DIR/AMDSEV
    git clone https://github.com/AMDESE/AMDSEV.git --branch snp-latest --depth 1 $AMDPATH
	if [[ $USE_STABLE_SNAPSHOT -eq 1 ]]; then
		echo "Switching to stable snapshtos for kernel, qemu and OVMF"
		cp  "$SCRIPT_DIR/snpguard-stable-commits.txt" "$AMDPATH/stable-commits"
  	fi
else
  echo "Using AMDSEV repository: $(realpath $AMDPATH)"
fi

pushd $AMDPATH 2>/dev/null

echo "Applying patches"
git apply $SCRIPT_DIR/patches/*.patch

./build.sh --package

echo "Move SNP dir to root"
mv snp-release-*/ $BUILD_DIR/snp-release/

popd