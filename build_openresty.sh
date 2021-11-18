#!/usr/bin/env bash
set -euo pipefail
set -x

OR_PREFIX=${OR_PREFIX:="/usr/local/openresty"}
OUTPUT=output

# gcc from 4 -> 9
# openresty-openssl-devel
# openresty-pcre-devel
# openresty-zlib-devel
install_dependencies() {
  sudo yum -y install centos-release-scl
  sudo yum -y install devtoolset-9 patch wget git make sudo zlib-devel
  set +eu
  source scl_source enable devtoolset-9
  set -eu
  command -v gcc
  gcc --version

  sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
  sudo yum -y install openresty-openssl111-devel openresty-pcre-devel openresty-zlib-devel
}


ngx_multi_upstream_module_ver="-b 1.0.0"
apisix_nginx_module_ver="-b 1.3.1"
lua_var_nginx_module_ver="-b v0.5.2"
or_ver="1.19.3.2"

download_sources() {
  workdir=$OUTPUT

  [[ -d $workdir ]] || mkdir $workdir

  pushd $workdir > /dev/null;
  # openresty
  wget --no-check-certificate https://openresty.org/download/openresty-${or_ver}.tar.gz
  tar -zxvpf openresty-${or_ver}.tar.gz > /dev/null

  [[ -d "ngx_multi_upstream_module" ]] || git clone --depth=1 $ngx_multi_upstream_module_ver https://github.com/api7/ngx_multi_upstream_module.git
  [[ -d "apisix-nginx-module" ]] || git clone --depth=1 $apisix_nginx_module_ver https://github.com/api7/apisix-nginx-module.git
  [[ -d "lua-var-nginx-module" ]] || git clone --depth=1 $lua_var_nginx_module_ver https://github.com/api7/lua-var-nginx-module

  cd ngx_multi_upstream_module || exit 1
  ./patch.sh ../openresty-${or_ver}
  cd ..

  cd apisix-nginx-module/patch || exit 1
  ./patch.sh ../../openresty-${or_ver}
  cd ../..

  popd > /dev/null;
}

export_openresty_variables() {
  export openssl_prefix=/usr/local/openresty/openssl111
  export zlib_prefix=/usr/local/openresty/zlib
  export pcre_prefix=/usr/local/openresty/pcre
  export OR_PREFIX

  export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${zlib_prefix}/include -I${pcre_prefix}/include -I${openssl_prefix}/include"
  export ld_opt="-L${zlib_prefix}/lib -L${pcre_prefix}/lib -L${openssl_prefix}/lib -Wl,-rpath,${zlib_prefix}/lib:${pcre_prefix}/lib:${openssl_prefix}/lib"
}

build_apisix_openrestry() {
  export_openresty_variables
  workdir=$OUTPUT

  [[ -d $workdir ]] || mkdir $workdir

  pushd $workdir > /dev/null;

  version=${version:-0.0.0}
  cc_opt=${cc_opt:-}
  ld_opt=${ld_opt:-}
  luajit_xcflags=${luajit_xcflags:="-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT"}
  no_pool_patch=${no_pool_patch:-}

  cd openresty-${or_ver} || exit 1
  ./configure --prefix="$OR_PREFIX" \
    --with-cc-opt="-DAPISIX_BASE_VER=$version $cc_opt" \
    --with-ld-opt="-Wl,-rpath,$ld_opt" \
    --add-module=../ngx_multi_upstream_module \
    --add-module=../apisix-nginx-module \
    --add-module=../lua-var-nginx-module \
    --with-poll_module \
    --with-pcre-jit \
    --without-http_rds_json_module \
    --without-http_rds_csv_module \
    --without-lua_rds_parser \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_v2_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_random_index_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-threads \
    --with-compat \
    --with-luajit-xcflags="$luajit_xcflags" \
    $no_pool_patch \
    -j`nproc`

  make -j`nproc`
  cd ..

  cd apisix-nginx-module || exit 1
  OPENRESTY_PREFIX="$OR_PREFIX" make 
  cd ..

  popd > /dev/null;
}


install() {
  workdir=$OUTPUT
  [[ -d $workdir ]] || mkdir $workdir
  pushd $workdir > /dev/null;

  cd openresty-${or_ver} || exit 1

  make install
  cd ..

  cd apisix-nginx-module || exit 1
  OPENRESTY_PREFIX="$OR_PREFIX" make install
  cd ..

  popd > /dev/null;
}

test() {
  echo test;
}

main() {
  if [ $# -gt 0 ] ; then $1; exit $?; fi

  install_dependencies;
  download_sources;
  export_openresty_variables;
  build_apisix_openrestry;
  install;
}

main $*
