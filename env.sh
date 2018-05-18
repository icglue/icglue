
src=${BASH_SOURCE:-$_}
pkgsrcpath=$(dirname $(readlink -e "${src}"))

export PATH="${PATH}:${pkgsrcpath}/bin"
MANPATH=${MANPATH:-/usr/share/man}
export MANPATH="${MANPATH}:${pkgsrcpath}/doc/ICGlue/man"

unset src
unset pkgsrcpath
