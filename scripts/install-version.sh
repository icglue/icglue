#!/bin/bash

src=$1
dest=$2

if [[ ! -f "$src" ]]; then
    echo "${src}: No such file"
fi
if [[ -z $dest ]]; then
    echo "Usage: $0 SOURCE DESTINATION"
fi

install -m755 -D -T $src $dest

version=""
if [[ $(which git 2> /dev/null) ]] ; then
    if [[ -n "$(git ls-files $src 2> /dev/null)" ]]; then
        version="$(git describe --tags --always --dirty)"
    fi
fi

replace="$(printf 's/(set additionalversion_str) "INSTALLED-VERSION"/\\1 "%s"/' "${version}")"
if sed -i -re "$replace" $dest ; then
    [[ -n "$version" ]] && version=" ($version)"
    echo "$(basename ${dest}) install as version ICGlue 4.1$version"
else
    echo "install version failed!"
    exit 1
fi

exit 0

