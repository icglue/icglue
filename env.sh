
src=${BASH_SOURCE:-$_}
pkgsrcpath=$(dirname $(readlink -e "${src}"))

export PATH="${PATH}:${pkgsrcpath}/bin"
MANPATH=${MANPATH:-/usr/share/man}
export MANPATH="${MANPATH}:${pkgsrcpath}/share/man:${pkgsrcpath}/doc/ICGlue/man"


alias icg='icglue --nocopyright'

if [[ -n ${ZSH_VERSION} ]] ; then
    compdef _gnu_generic icglue
fi

unset src
unset pkgsrcpath
