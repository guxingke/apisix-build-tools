#!/usr/bin/env bash
set -euo pipefail
set -x

APISIX_PREFIX=${OR_PREFIX:="/usr/local/apisix"}
OUTPUT=${OUTPUT:"tmp"}

cd $OUTPUT

# install LuaRocks
curl https://raw.githubusercontent.com/apache/apisix/master/utils/linux-install-luarocks.sh -sL | bash -

# apisix
mkdir apisix-2.10.1
wget https://downloads.apache.org/apisix/2.10.1/apache-apisix-2.10.1-src.tgz
tar zxvf apache-apisix-2.10.1-src.tgz -C apisix-2.10.1

# 添加 openrestry 到 path 

cd apisix-2.10.1
make deps OPENSSL_PREFIX=/usr/local/openresty/openssl111

ln -snf `pwd` $APISIX_PREFIX
