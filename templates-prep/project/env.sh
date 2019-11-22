#
# this is  bash and zsh compatible script,
# which should be placed in the icpro project root.
#
# source this script to setup the icpro project enviroment by providing
#
#    - $ICPRO_DIR variable
#    - cdi, cdu, cds function to change directories
#    - completions for the upper functions
#    - prompt shortening
#

src=${BASH_SOURCE:-$_}
export ICPRO_DIR=$(dirname $(readlink -e $src))
unset src

[[ -n "$(declare -f -F icpro_cd)" ]] || icpro_cd() {
    local flags
    local dir
    if [[ -n "$ICPRO_DIR" ]] ; then
        dir=$ICPRO_DIR$1
        shift
        if [[ $1 = "-P" || $1 == "-L" ]] ; then
            flags=$1
            shift
        fi

        cd $flags ${dir%/}/$@
    else
        echo '$ICPRO_DIR environment variable not set'
    fi
}

[[ -n "$(declare -f -F cdi)" ]] || cdi() {
    icpro_cd / $@
}
[[ -n "$(declare -f -F cdu)" ]] || cdu() {
    icpro_cd /units $@
}
[[ -n "$(declare -f -F cds)" ]] || cds () {
    icpro_cd /software $@
}

if [[ -n "$BASH_VERSION" ]]; then
    for f in cdi cdu cds ; do
        eval "_bashcomp_$f() { COMPREPLY=(\$($f > /dev/null 2> /dev/null && compgen -A directory -S / -- \$2)) ; }"
        complete -o nospace -F _bashcomp_$f $f
    done
    if [[ -z $PROMPT_COMMAND ]] ; then
        _icpro_prompt () {
            PS1=$(echo "${_icpro_prompt_base@P}" | sed -e "s#${ICPRO_DIR/$HOME/\~}#ICPRO_DIR#g")
        }
        _icpro_prompt_base="$PS1"
        export PROMPT_COMMAND=_icpro_prompt
    fi
fi

if [[ -n "$ZSH_VERSION" ]]; then
    : ~ICPRO_DIR
    compctl -W $ICPRO_DIR/          -/ cdi
    compctl -W $ICPRO_DIR/units/    -/ cdu
    compctl -W $ICPRO_DIR/software/ -/ cds
fi

icpro_logout() {
    if [[ -n "$(declare -f -F _icpro_prompt)" ]] ; then
        PS1="$_icpro_prompt_base"
        unset -f _icpro_prompt
        unset _icpro_prompt_base
        unset PROMPT_COMMAND
    fi
    unset ICPRO_DIR
}
