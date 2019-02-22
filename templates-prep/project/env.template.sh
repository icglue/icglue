src=${BASH_SOURCE:-$_}

export ICPRO_DIR=$(dirname $(readlink -e $src))
unset src

if alias cdi &> /dev/null ; then unalias cdi ; fi
if alias cdu &> /dev/null ; then unalias cdu ; fi
if alias cds &> /dev/null ; then unalias cds ; fi

function cdi () {
    if [ "_$ICPRO_DIR" != "_" ] ; then
        cd "$ICPRO_DIR/$@"
    else
        echo '$ICPRO_DIR environment variable not set'
    fi
}
function cdu () {
    if [ "_$ICPRO_DIR" != "_" ] ; then
        cd "$ICPRO_DIR/units/$@"
    else
        echo '$ICPRO_DIR environment variable not set'
    fi
}
function cds () {
    if [ "_$ICPRO_DIR" != "_" ] ; then
        cd "$ICPRO_DIR/software/$@"
    else
        echo '$ICPRO_DIR environment variable not set'
    fi
}

if echo "$SHELL" | grep zsh &> /dev/null ; then
    compctl -W $ICPRO_DIR/ -/ cdi
    compctl -W $ICPRO_DIR/units/ -/ cdu
    compctl -W $ICPRO_DIR/software/ -/ cds
fi

