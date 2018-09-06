#!/bin/bash

icglue_modhome=$HOME/workspace/icglue

if [[ $1 -ne "" ]] ; then
    icglue_modhome=$(readlink -e $1)
fi

if [[ ! -e ${icglue_modhome}/bin/icglue ]] ; then
    echo "ERROR: File ${icglue_modhome}/bin/icglue not found. - No valid setup detected!"
    exit 1
fi

if [[ ! -e $HOME/.modules/icglue/user ]] ; then
    echo "INFO: Creating $HOME/.modules/icglue/user"
    sed module/modulefile.tcl -r -e 's#(set tool_root)\s+.*#\1 "'$icglue_modhome'"#' > $HOME/.modules/icglue/user
else
    echo "INFO: $HOME/.modules/icglue/user already exists"
fi

if [[ -n $MODULEPATH ]] ; then
    for rc in $HOME/{.bashrc,.cshrc,.zshrc} ; do
        if [[ ! -e $rc ]] ; then
            touch $rc
        fi
        if grep -q 'module use -a $HOME/.modules' $rc ; then
            echo "INFO: $rc already contains module setup"
        else
            echo "INFO: Adding $HOME/.modules enviroment to $rc"
            echo 'module use -a $HOME/.modules' >> $rc
        fi
    done
    echo 'INFO: Module setup done -- source your shell-rc and use `module load icglue/user` to add icglue to your enviroment'
fi

