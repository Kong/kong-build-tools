#!/bin/bash

set -eu

if (( ${DEBUG:-0} == 1 )); then
    set -x
fi

# ubuntu | debian | centos | amazonlinux | alpine | rhel
readonly DISTRO_NAME=${RESTY_IMAGE_BASE:?RESTY_IMAGE_BASE is required}

# typically this is a version number (e.g. "7" or "18.04"), but sometimes
# it is a label/nickname corresponding to that version instead (e.g. "bionic")
readonly DISTRO_VERSION=${RESTY_IMAGE_TAG:?RESTY_IMAGE_TAG is required}

# linux/amd64  => amd64
# linux/arm/v7 => arm
PLATFORM_ARCH=${TARGETPLATFORM:?TARGETPLATFORM is required}
PLATFORM_ARCH=${PLATFORM_ARCH#*/}
readonly PLATFORM_ARCH=${PLATFORM_ARCH%%/*}

# deb | rpm | apk
readonly PACKAGE_TYPE=${PACKAGE_TYPE:?PACKAGE_TYPE is required}

# Kong tag or Kong version
readonly PACKAGE_VERSION=${KONG_RELEASE_LABEL:?KONG_RELEASE_LABEL is required}

PACKAGE_NAME=${KONG_PACKAGE_NAME:-kong}

readonly KONG_CE=kong-community-edition
readonly KONG_EE=kong-enterprise-edition
readonly KONG_EE_FIPS=kong-enterprise-edition-fips

PACKAGE_PROVIDES=${PACKAGE_PROVIDES:-kong-community-edition}
PACKAGE_CONFLICTS=( "${PACKAGE_CONFLICTS:-kong-enterprise-edition}" )
PACKAGE_REPLACES=( "${PACKAGE_REPLACES:-kong-community-edition}" )

# openssl | boringssl
readonly SSL_PROVIDER=${SSL_PROVIDER:-openssl}

case "$PACKAGE_NAME/$SSL_PROVIDER" in
  kong/*)
    PACKAGE_CONFLICTS=( "$KONG_EE" "$KONG_EE_FIPS" )
    PACKAGE_REPLACES=( "$KONG_CE" )
    ;;

  kong-enterprise-edition/*)
    PACKAGE_CONFLICTS=( "$KONG_CE" "$KONG_EE_FIPS" )
    PACKAGE_REPLACES=( "$KONG_CE" )
    ;;

  kong-enterprise-edition-fips/* | */boringssl )
    # normalize the package name if needed
    PACKAGE_NAME=kong-enterprise-edition-fips

    PACKAGE_CONFLICTS=( "$KONG_CE" "$KONG_EE" )
    PACKAGE_REPLACES=( "$KONG_CE" )
    ;;

  *)
    echo "Fatal: unexpected PACKAGE_NAME ($PACKAGE_NAME) or SSL_PROVIDER ($SSL_PROVIDER)"
    exit 1
    ;;
esac

_PREFIX=/output/${PACKAGE_NAME}-${PACKAGE_VERSION}
PACKAGE_FILENAME=
case "$PACKAGE_TYPE/$DISTRO_NAME" in
  apk/*)
    PACKAGE_FILENAME=${_PREFIX}.${PLATFORM_ARCH}.apk.tar.gz
    ;;

  deb/*)
    PACKAGE_FILENAME=${_PREFIX}.${DISTRO_VERSION}.${PLATFORM_ARCH}.deb
    ;;

  rpm/amazonlinux)
    PACKAGE_FILENAME=${_PREFIX}.aws.${PLATFORM_ARCH}.rpm
    ;;

  rpm/centos)
    PACKAGE_FILENAME=${_PREFIX}.el${DISTRO_VERSION}.${PLATFORM_ARCH}.rpm
    ;;

  rpm/*)
    PACKAGE_FILENAME=${_PREFIX}.rhel${DISTRO_VERSION}.${PLATFORM_ARCH}.rpm
    ;;

  *)
    echo "Fatal: unknown PACKAGE_TYPE ($PACKAGE_TYPE) or DISTRO_NAME ($DISTRO_NAME)"
    exit 1
    ;;
esac
readonly PACKAGE_FILENAME


PACKAGE_DEPS=(perl)
case "$PACKAGE_TYPE/$DISTRO_NAME/$DISTRO_VERSION" in
  apk/*)
    PACKAGE_DEPS=()
    ;;

  deb/*/*)
    PACKAGE_DEPS+=( libpcre3
                    zlib1g-dev
    ) ;;

  rpm/*/*)
    PACKAGE_DEPS+=( pcre
                    perl-Time-HiRes
                    zlib
                    zlib-devel
    ) ;;&

  rpm/*/7)
    PACKAGE_DEPS+=( hostname
    ) ;;&

  rpm/amazonlinux/*)
    PACKAGE_DEPS+=( /usr/sbin/useradd
                    /usr/sbin/groupadd
    ) ;;&

  *)
    ;;
esac

echo "Building package..."
echo ">>>"
echo "         name: $PACKAGE_NAME"
echo "      version: $PACKAGE_VERSION"
echo "         type: $PACKAGE_TYPE"
echo "       distro: $DISTRO_NAME $DISTRO_VERSION"
echo "         arch: $PLATFORM_ARCH"
echo "     provides: $PACKAGE_PROVIDES"
echo "     replaces: ${PACKAGE_REPLACES[*]}"
echo "    conflicts: ${PACKAGE_CONFLICTS[*]}"
echo " dependencies: ${PACKAGE_DEPS[*]}"
echo "     filename: $PACKAGE_FILENAME"
echo "<<<"

mkdir /output
cd /tmp/build || {
  echo "Fatal: expected /tmp/build directory to exist"
  exit 1
}

case "$PACKAGE_TYPE" in
  apk)
    tar -zcvf \
      "$PACKAGE_FILENAME" \
      usr etc
    ;;

  deb | rpm )
    FPM_PARAMS=()
    for dep in "${PACKAGE_DEPS[@]}"; do
      FPM_PARAMS+=(-d "$dep")
    done

    for c in "${PACKAGE_CONFLICTS[@]}"; do
      FPM_PARAMS+=(--conflicts "$c")
    done

    for r in "${PACKAGE_REPLACES[@]}"; do
      FPM_PARAMS+=(--replaces "$r")
    done

    fpm -f -s dir \
      -t "$PACKAGE_TYPE" \
      -m 'support@konghq.com' \
      -n "$PACKAGE_NAME" \
      -v "$PACKAGE_VERSION" \
      "${FPM_PARAMS[@]}" \
      --description 'Kong is a distributed gateway for APIs and Microservices, focused on high performance and reliability.' \
      --vendor 'Kong Inc.' \
      --license "ASL 2.0" \
      --provides "$PACKAGE_PROVIDES" \
      --after-install '/after-install.sh' \
      --url 'https://getkong.org/' \
      usr etc lib

    mv kong*.* "$PACKAGE_FILENAME"

    if [[ $PACKAGE_TYPE == rpm ]] && [[ -n "${PRIVATE_KEY_PASSPHRASE:-}" ]]; then
      apt-get update
      apt-get install -y expect
      mkdir -p ~/.gnupg/
      touch ~/.gnupg/gpg.conf
      echo use-agent >> ~/.gnupg/gpg.conf
      echo pinentry-mode loopback >> ~/.gnupg/gpg.conf
      echo allow-loopback-pinentry >> ~/.gnupg/gpg-agent.conf
      echo RELOADAGENT | gpg-connect-agent
      cp /.rpmmacros ~/
      gpg --batch --import /kong.private.asc
      /sign-rpm.exp "$PACKAGE_FILENAME"
    fi
    ;;
esac
