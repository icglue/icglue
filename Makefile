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

LIBDIR               := lib
LIBSOURCES           := $(LIBDIR)/binaries/icglue.so
TCLSOURCES           := $(wildcard tcllib/*.tcl)
PKGDIR               := ICGlue

PKGIDX               := $(PKGDIR)/pkgIndex.tcl
PKGGENSCR            := scripts/tcl_pkggen.tcl

VERSION              := 2.0a1
VERSIONSCR           := scripts/update_version.sh
VERSIONSCRINSTALL    := scripts/install-version.sh

DOCDIR               := doc
DOCDIRTCL            := $(DOCDIR)/ICGlue
DOCDIRLIB            := $(DOCDIR)/ICGlue-Lib
DOXYFILETCL          := doxy/tcl.doxyfile
DOXYFILELIB          := doxy/lib.doxyfile

BROWSER              ?= firefox

MANSEC               := 1
MANDIR               := share/man/man$(MANSEC)
H2MBASENAMES         := icglue icsng2icglue

SYNTAXDIR            := nagelfar
SYNTAXFILE_LIB       := $(SYNTAXDIR)/ICGlue.nagelfar.db.tcl
SYNTAXFILE_CNSTR     := $(SYNTAXDIR)/ICGlue_construct.nagelfar.db.tcl
NAGELFAR_SYNTAXBUILD := /usr/lib/nagelfar/syntaxbuild.tcl
SYNTAXGEN_LIB        := scripts/gen_nagelfar_db.tcl
SYNTAXGEN_CNSTR      := scripts/gen_nagelfar_db_construct.tcl

TEMPLATES            := templates
PREFIX               ?= $(CURDIR)/install
DESTDIR              ?=
INSTDIR              := $(DESTDIR)$(PREFIX)

LOCTOOL              ?= cloc
LOCSOURCES           := $(wildcard tcllib/*.tcl bin/* lib/*.c lib/*.h)
LOCTEMPLATES         := $(wildcard templates/*/*)
LOCEXTRA             := $(wildcard scripts/* vim/*/*.vim vim/*/*/*.vim) Makefile lib/Makefile

#-------------------------------------------------------
# Tcl Package
all: prebuild
	@$(MAKE) $(PKGIDX)

prebuild $(LIBSOURCES):
	@$(MAKE) -C $(LIBDIR)

$(PKGIDX): $(TCLSOURCES) $(LIBSOURCES) $(PKGGENSCR) | $(PKGDIR)
	rm -f $(PKGIDX)
	@for S in  $(LIBSOURCES) $(TCLSOURCES); do  \
		echo "ln -sft $(PKGDIR) ../$$S"; \
		ln -sft $(PKGDIR) ../$$S; \
	done
	$(PKGGENSCR) $(PKGDIR)

.PHONY: all prebuild

#-------------------------------------------------------
# version number/header update
updateversion:
	$(VERSIONSCR) $(VERSION)
	$(MAKE)
	$(MAKE) man

.PHONY: updateversion

#-------------------------------------------------------
# documentation
doctcl: $(DOXYFILETCL) | $(DOCDIRTCL)
	-doxygen $(DOXYFILETCL)

doclib: $(DOXYFILELIB) | $(DOCDIRLIB)
	-doxygen $(DOXYFILELIB)

docs: doctcl doclib

showdocs:
	$(BROWSER) $(DOCDIRLIB)/html/index.html $(DOCDIRTCL)/html/index.html > /dev/null 2> /dev/null &

$(MANDIR):
	-mkdir -p $(MANDIR)

$(MANDIR)/%.$(MANSEC): ./h2m/%.h2m ./bin/% | $(MANDIR)
	-help2man -N -i ./h2m/$*.h2m ./bin/$* > $@
	sed -i -e 's/(INSTALLED-VERSION)//' $@

man: $(addprefix $(MANDIR)/, $(addsuffix .$(MANSEC), $(H2MBASENAMES)))

.PHONY: doctcl doclib docs man

#-------------------------------------------------------
# syntax check
syntaxdb: $(SYNTAXFILE_LIB) $(SYNTAXFILE_CNSTR)

$(SYNTAXFILE_LIB): $(PKGIDX) | $(SYNTAXDIR)
	-NAGELFAR_SYNTAXBUILD=$(NAGELFAR_SYNTAXBUILD) $(SYNTAXGEN_LIB) $(SYNTAXFILE_LIB)

$(SYNTAXFILE_CNSTR): $(PKGIDX) | $(SYNTAXDIR)
	-NAGELFAR_SYNTAXBUILD=$(NAGELFAR_SYNTAXBUILD) $(SYNTAXGEN_CNSTR) $(SYNTAXFILE_CNSTR)

.PHONY: syntaxdb

#-------------------------------------------------------
# build everything
everything: all syntaxdb docs man

shell:
	@TCLLIBPATH=. eltclsh scripts/elinit.tcl

memcheck:
	TCLLIBPATH=. G_SLICE=always-malloc valgrind --leak-check=full eltclsh scripts/elinit.tcl

.PHONY: everything shell memcheck

#-------------------------------------------------------
# install
install: install_bin install_doc install_helpers

install_bin:
	install -m755 -d $(INSTDIR)/lib/icglue/$(PKGDIR)
	install -m644    $(PKGDIR)/*.tcl -t                $(INSTDIR)/lib/icglue/$(PKGDIR)
	install -m755 -s $(PKGDIR)/*.so -t                 $(INSTDIR)/lib/icglue/$(PKGDIR)
	$(VERSIONSCRINSTALL) ./bin/icglue                  $(INSTDIR)/lib/icglue/icglue
	install -m755 -D ./bin/icsng2icglue -T             $(INSTDIR)/lib/icglue/icsng2icglue
	install -m755 -d $(INSTDIR)/bin
	ln -sf           $(PREFIX)/lib/icglue/icglue       $(INSTDIR)/bin/icglue
	ln -sf           $(PREFIX)/lib/icglue/icsng2icglue $(INSTDIR)/bin/icsng2icglue
	install -m755 -d $(INSTDIR)/share/icglue
	cp -r            $(TEMPLATES)                      $(INSTDIR)/share/icglue

install_doc:
	install -m755 -d $(INSTDIR)/share/icglue
	install -m755 -d $(INSTDIR)/$(MANDIR)
	install -D       $(CURDIR)/$(MANDIR)/*            $(INSTDIR)/$(MANDIR)
	-cp     -r       $(DOCDIRTCL)/man                 $(INSTDIR)/share
	-cp     -r       $(DOCDIRTCL)/html                $(INSTDIR)/share/icglue
	sed -i -e 's#%DOCDIRTCL%#$(PREFIX)/share/icglue#' $(INSTDIR)/share/man/man1/icglue.$(MANSEC)

install_helpers:
	install -m755 -d $(INSTDIR)/share/icglue
	cp -r            $(CURDIR)/vim            $(INSTDIR)/share/icglue     # vim
	-cp -r           $(SYNTAXDIR)             $(INSTDIR)/share/icglue     # nagelfar

.PHONY: install install_bin install_doc install_helpers

#-------------------------------------------------------
# LoC
loc:
	@$(LOCTOOL) $(LOCSOURCES)

locall:
	@$(LOCTOOL) $(LOCSOURCES) $(LOCEXTRA) $(LOCTEMPLATES)

.PHONY: loc locall

#-------------------------------------------------------
# directories
$(PKGDIR) $(DOCDIR) $(DOCDIRTCL) $(DOCDIRLIB) $(SYNTAXDIR):
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

mrproper cleanall: clean cleandoc cleansyntax
	@$(MAKE) -C $(LIBDIR) clean

.PHONY: mrproper cleanall clean cleandoc cleansyntax
