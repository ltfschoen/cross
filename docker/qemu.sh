set -ex

main() {
    local version=4.0.0

    local arch=$1 \
          os=$2 \
          softmmu=$3 \
          td=$(mktemp -d)

    local dependencies=(
        autoconf
        automake
        bison
        bzip2
        curl
        flex
        g++
        libglib2.0-dev
        libtool
        make
        patch
        pkg-config
        python
        zlib1g-dev
        libcap-dev
        libattr1-dev
        libpixman-1-dev
        xz-utils
    )

    apt-get update
    local purge_list=()
    for dep in ${dependencies[@]}; do
        if ! dpkg -L $dep; then
            apt-get install --no-install-recommends -y $dep
            purge_list+=( $dep )
        fi
    done

    pushd $td

    curl -L https://download.qemu.org/qemu-$version.tar.xz | \
        tar --strip-components=1 -xJ

   local targets="$arch-linux-user"
   local virtfs=""
   case "$softmmu" in
      softmmu)
         if [ "$arch" = "ppc64le" ]; then
            targets="$targets,ppc64-softmmu"
         else
            targets="$targets,$arch-softmmu"
         fi
         virtfs="--enable-virtfs"
         ;;
      "")
         true
         ;;
      *)
         echo "Invalid softmmu option: $softmmu"
         exit 1
         ;;
   esac

    ./configure \
        --disable-kvm \
        --disable-vnc \
        --enable-user \
        --static \
        $virtfs \
        --target-list=$targets
    nice make -j$(nproc)
    make install

    # HACK the binfmt_misc interpreter we'll use expects the QEMU binary to be
    # in /usr/bin. Create an appropriate symlink
    ln -s /usr/local/bin/qemu-$arch /usr/bin/qemu-$arch-static

    # Clean up
    apt-get purge --auto-remove -y ${purge_list[@]}

    popd

    rm -rf $td
    rm $0
}

main "${@}"
