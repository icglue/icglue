
src=${BASH_SOURCE:-$_}
pkgsrcpath=$(dirname $(readlink -e "${src}"))

export PATH="${pkgsrcpath}/bin:${PATH}"
MANPATH=${MANPATH:-/usr/share/man}
export MANPATH="${MANPATH}:${pkgsrcpath}/share/man:${pkgsrcpath}/doc/ICGlue/man"


alias icg='icglue --nocopyright'

if [[ -n ${ZSH_VERSION} ]] ; then
    (( $+functions[_icglue] )) || {
        fpath+=($pkgsrcpath/share/zsh/site-functions)
        autoload _icglue
        compdef _icglue icglue
    }
fi

unset src
unset pkgsrcpath
