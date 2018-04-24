
src=${BASH_SOURCE:-$_}
pkgsrcpath=$(readlink -e $(dirname $(readlink -e "${src}"))/..)

if [[ "x${TCLLIBPATH}" == "x" ]] ; then
    export TCLLIBPATH="${pkgsrcpath}"
else
    export TCLLIBPATH="${TCLLIBPATH}:${pkgsrcpath}"
fi

unset src
unset pkgsrcpath
