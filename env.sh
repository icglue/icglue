
src=${BASH_SOURCE:-$_}
pkgsrcpath=$(dirname $(readlink -e "${src}"))

export PATH="${PATH}:${pkgsrcpath}/bin"

unset src
unset pkgsrcpath
