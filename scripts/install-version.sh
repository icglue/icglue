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
        gitrev=$(git rev-parse --short HEAD)
        gitdirty=""
        [[ -n "$(git diff --shortstat)" ]] && gitdirty="-dirty"
        version=" (git-rev ${gitrev}${gitdirty})"
    fi
fi

replace="$(printf 's/(set additionalversion_str) "INSTALLED-VERSION"/\\1 "%s"/' "${version}")"
sed -i -re "$replace" $dest \
    && echo "$(basename ${dest}) install as version ICGlue 3.0$version"

exit 0

