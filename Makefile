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

LIBDIR           := lib
LIBSOURCES       := $(LIBDIR)/binaries/icglue.so
TCLSOURCES       := $(wildcard tcllib/*.tcl)
PKGDIR           := ICGlue

PKGIDX           := $(PKGDIR)/pkgIndex.tcl
PKGGENSCR        := scripts/tcl_pkggen.tcl

VERSION          := 1.0a1
VERSIONSCR       := scripts/update_version.sh

DOCDIR           := doc
DOCDIRTCL        := $(DOCDIR)/ICGlue
DOCDIRLIB        := $(DOCDIR)/ICGlue-Lib
DOXYFILETCL      := doxy/tcl.doxyfile
DOXYFILELIB      := doxy/lib.doxyfile

BROWSER          ?= firefox

SYNTAXDIR        := nagelfar
SYNTAXFILE_LIB   := $(SYNTAXDIR)/ICGlue.nagelfar.db.tcl
SYNTAXFILE_CNSTR := $(SYNTAXDIR)/ICGlue_construct.nagelfar.db.tcl
SYNTAXGEN_LIB    := scripts/gen_nagelfar_db.tcl
SYNTAXGEN_CNSTR  := scripts/gen_nagelfar_db_construct.tcl

BINSCRIPT        := bin/icglue
DESTDIR          ?= install/usr
DESTDIREXE       := $(DESTDIR)/bin
DESTDIRPKG       := $(DESTDIR)/lib/icglue/ICGlue
DESTDIRBIN       := $(DESTDIR)/lib/icglue/bin
DESTDIRAUX       := $(DESTDIR)/share/icglue

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
syntaxdb: $(SYNTAXFILE_LIB) $(SYNTAXFILE_CNSTR)

$(SYNTAXFILE_LIB): $(PKGIDX) | $(SYNTAXDIR)
	$(SYNTAXGEN_LIB) $(SYNTAXFILE_LIB)

$(SYNTAXFILE_CNSTR): $(PKGIDX) | $(SYNTAXDIR)
	$(SYNTAXGEN_CNSTR) $(SYNTAXFILE_CNSTR)

.PHONY: syntaxdb

#-------------------------------------------------------
# build everything
everything: all syntaxdb docs

shell:
	TCLLIBPATH=. eltclsh scripts/elinit.tcl

memcheck:
	TCLLIBPATH=. G_SLICE=always-malloc valgrind --leak-check=full eltclsh scripts/elinit.tcl

.PHONY: everything shell memcheck

#-------------------------------------------------------
# install
install: all syntaxdb docs | $(DESTDIR)
	install -m755 -d $(DESTDIRPKG)
	install -m644 $(PKGDIR)/*.tcl -t $(DESTDIRPKG)
	install -m755 $(PKGDIR)/*.so -t $(DESTDIRPKG)
	install -m755 -D $(BINSCRIPT) -t $(DESTDIRBIN)/
	install -m755 -d $(DESTDIREXE)
	ln -rfs $(DESTDIRBIN)/icglue $(DESTDIREXE)/icglue
	install -m755 -d $(DESTDIRAUX)
	cp -r $(DOCDIRTCL)/man $(DESTDIRAUX)
	cp -r $(DOCDIRTCL)/html $(DESTDIRAUX)
	cp -r vim $(DESTDIRAUX)
	cp -r $(SYNTAXDIR) $(DESTDIRAUX)


.PHONY: install

#-------------------------------------------------------
# directories
$(PKGDIR) $(DOCDIR) $(DOCDIRTCL) $(DOCDIRLIB) $(SYNTAXDIR) $(DESTDIR):
	mkdir -p $@


#-------------------------------------------------------
# cleanup targets
clean:
	rm -rf $(PKGDIR)
	rm -rf install

cleandoc:
	rm -rf $(DOCDIR)

cleansyntax:
	rm -rf $(SYNTAXDIR)

cleanall: clean cleandoc cleansyntax
	@$(MAKE) -C $(LIBDIR) clean

.PHONY: clean cleanall cleandoc cleansyntax
