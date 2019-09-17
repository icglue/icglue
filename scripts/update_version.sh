#!/bin/bash

die() {
    echo $@
    exit 1
}

git diff-index --quiet HEAD  || die "Git working directory is not clean - Please stash or commit or changes."
version=$1
if [[ -z $1 ]]; then
    echo -n "Enter Version number: "
    read version
fi

VERSION=$(echo "$version" | sed -e 's#\.#\\\.#g')
YEAR=$(date '+%Y')

FILES_VERSION=$(find . -type f -and '(' -name \*.c -or -name \*.h -or -name \*.tcl -or -iname README\* ')' )
FILES_DATE=$(find . -type f -and '(' -name \*.c -or -name \*.h -or -name \*.tcl -or -iname Makefile -or -iname README\* ')' )

for f in $FILES_VERSION scripts/*.tcl scripts/install-version.sh bin/* logo/info.txt ; do
    sed -r -e 's#(ICGlue.*[^0-9ab\.])[0-9]+(\.[0-9ab]+){0,3}#\1'${VERSION}'#' -i $f
done

for f in $FILES_DATE bin/* ; do
    sed -r -e 's#(Copyright.*[0-9]{4}-)[0-9]{4}#\1'${YEAR}'#' -i $f
done

make || die "build failed"
make man || die "man update failed"

if [[ $version =~ [ab] ]] ; then
    echo "Commit version $version..."
    git commit -a -m "version update to $version" || die "git commit failed"
    echo "Skip tagging -- Version is alpha/beta"
else
    echo "Commit version $version..."
    git commit -a -m "release version $version" || die "git commit failed"
    echo "Tag version $v$version..."
    git tag "v$version" || die "git tag failed"

fi

echo "Version bump done - Review changes before using 'git push --tags' to upstream changes"

