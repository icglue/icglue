
src=${BASH_SOURCE:-$_}
pkgsrcpath=$(dirname $(readlink -e "${src}"))

export PATH="${PATH}:${pkgsrcpath}/bin"
MANPATH=${MANPATH:-/usr/share/man}
export MANPATH="${MANPATH}:${pkgsrcpath}/share/man:${pkgsrcpath}/doc/ICGlue/man"


if [[ -n ${ZSH_VERSION} ]] ; then
    # remove logo header
    eval "icg() { command icglue \$@ 2>&1 | tail -n+$(($(wc -l ${pkgsrcpath}/logo/logo.txt| cut -f1 -d" ") + 2)) }"

    compdef _gnu_generic icg
fi

unset src
unset pkgsrcpath
