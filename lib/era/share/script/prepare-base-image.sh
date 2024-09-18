#!/usr/bin/env bash
set -Eeuo pipefail

export LOCALE=C
export LC_ALL=C

EPOCROOT="$(mktemp -d)"

_cleanup () {
  &>/dev/null cd / ||:
  if [[ ! -z "${EPOCROOT}" ]] && mountpoint "${EPOCROOT}" &>/dev/null ; then
    sudo umount "${EPOCROOT}" &>/dev/null ||:
    rmdir "${EPOCROOT}" &>/dev/null \
      || >&2 echo "HEADS UP: You may need to remove the leftover directory from the temporary EPOCROOT at \"${EPOCROOT}\" manually!"
  fi
}

_err () {
  >&2 echo "Error $1 occurred at line $2 in script \"$3\""
  _cleanup
  exit "$1"
}

_int () {
  >&2 echo 'Interrupted...'
  _cleanup
  exit 130
}

trap '_err $? ${LINENO} "${BASH_SOURCE[0]}"' ERR
trap '_int' INT

BASE_IMAGE=$1

test -n "${BASE_IMAGE}"
test -d "$(dirname -- "${BASE_IMAGE}")"

rm -fiv "${BASE_IMAGE}" ||:

truncate -s 256M "${BASE_IMAGE}"
mkfs.ext4 -O casefold -E resize=33554432 -b 4096 "${BASE_IMAGE}"

sudo mount -o loop,relatime,X-mount.idmap=b:0:"$(id -u "${USER}")":1 "${BASE_IMAGE}" "${EPOCROOT}"

mkdir -p "${EPOCROOT}"/epoc32/sbs_config
mkdir -p "${EPOCROOT}"/epoc32/tools
mkdir -p "${EPOCROOT}"/epoc32/include
mkdir -p "${EPOCROOT}"/epoc32/release

chattr +F "${EPOCROOT}"/epoc32/include
chattr +F "${EPOCROOT}"/epoc32/release

sudo umount "${EPOCROOT}" &>/dev/null ||:

gzip <"${BASE_IMAGE}" |sponge "${BASE_IMAGE}"

_cleanup
