#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2018  Andreas Dixius, Felix Neumärker
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

LIBDIR      := lib
LIBSOURCES  := $(LIBDIR)/binaries/icglue.so
TCLSOURCES  := $(wildcard tcllib/*.tcl)
PKGDIR      := ICGlue

PKGIDX      := $(PKGDIR)/pkgIndex.tcl
PKGGENSCR   := scripts/tcl_pkggen.tcl

VERSION     := 1.0a1
VERSIONSCR  := scripts/update_version.sh

DOCDIR      := doc
DOCDIRTCL   := $(DOCDIR)/ICGlue
DOCDIRLIB   := $(DOCDIR)/ICGlue-Lib
DOXYFILETCL := doxy/tcl.doxyfile
DOXYFILELIB := doxy/lib.doxyfile

BROWSER     ?= firefox

SYNTAXDIR   := nagelfar
SYNTAXFILE  := $(SYNTAXDIR)/ICGlue.nagelfar.db.tcl
SYNTAXGEN   := scripts/gen_nagelfar_db.tcl

#-------------------------------------------------------
# Tcl Package
all: prebuild
	@$(MAKE) $(PKGIDX)

prebuild $(LIBSOURCES):
	@$(MAKE) -C $(LIBDIR)

$(PKGIDX): $(TCLSOURCES) $(LIBSOURCES) $(PKGGENSCR) | $(PKGDIR)
	rm -f $(PKGIDX)
	cp $(LIBSOURCES) $(PKGDIR)
	cp $(TCLSOURCES) $(PKGDIR)
	$(PKGGENSCR) $(PKGDIR)

.PHONY: all prebuild

#-------------------------------------------------------
# version number/header update
updateversion:
	$(VERSIONSCR) $(VERSION)

.PHONY: updateversion

#-------------------------------------------------------
# documentation
doctcl: $(DOXYFILETCL) | $(DOCDIRTCL)
	doxygen $(DOXYFILETCL)

doclib: $(DOXYFILELIB) | $(DOCDIRLIB)
	doxygen $(DOXYFILELIB)

docs: doctcl doclib

showdocs:
	$(BROWSER) $(DOCDIRLIB)/html/index.html $(DOCDIRTCL)/html/index.html > /dev/null 2> /dev/null &

.PHONY: doctcl doclib docs

#-------------------------------------------------------
# syntax check
syntaxdb: $(SYNTAXFILE)

$(SYNTAXFILE): $(PKGIDX) | $(SYNTAXDIR)
	$(SYNTAXGEN) $(SYNTAXFILE)

.PHONY: syntaxdb

#-------------------------------------------------------
# build everything
everything: all syntaxdb docs

shell:
	TCLLIBPATH=. eltclsh scripts/elinit.tcl

.PHONY: everything

#-------------------------------------------------------
# directories
$(PKGDIR) $(DOCDIR) $(DOCDIRTCL) $(DOCDIRLIB) $(SYNTAXDIR):
	mkdir -p $@


#-------------------------------------------------------
# cleanup targets
clean:
	rm -rf $(PKGDIR)

cleandoc:
	rm -rf $(DOCDIR)

cleansyntax:
	rm -rf $(SYNTAXDIR)

cleanall: clean cleandoc cleansyntax
	@$(MAKE) -C $(LIBDIR) clean

.PHONY: clean cleanall cleandoc cleansyntax
