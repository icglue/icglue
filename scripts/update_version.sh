#!/bin/sh

if [ "x$1" = "x" ] ; then
    echo "need a version number as argument"
    exit 1
fi

VERSION=$(echo $1 | sed -e 's#\.#\\\.#g')
YEAR=$(date '+%Y')

FILES_VERSION=$(find . -name \*.c -or -name \*.h -or -name \*.tcl -or -iname README\*)
FILES_DATE=$(find . -name \*.c -or -name \*.h -or -name \*.tcl -or -iname Makefile -or -iname README\*)

for f in $FILES_VERSION ; do
    sed -e "s#\\(ICGlue.*[^0-9ab\\.]\\)[0-9]\\+\\(\\.[0-9ab]\\+\\)\\{0,3\\}#\\1${VERSION}#" -i $f
done

for f in $FILES_DATE ; do
    sed -e "s#\\(Copyright.*[0-9]\\{4\\}-\\)[0-9]\\{4\\}#\\1${YEAR}#" -i $f
done

