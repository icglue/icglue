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

PROGS                ?= $(notdir $(wildcard bin/*))
STATIC_SHEBANG        = 1

DESTDIR              ?= $(CURDIR)/install
PREFIX               ?= /usr/local
LIBDIR                = lib
PKGNAME               = ICGlue
LIBNAME               = icglue.so

CLIBDIR               = lib
CLIBSOURCES           = $(CLIBDIR)/binaries/$(LIBNAME)
TCLSOURCES            = $(wildcard tcllib/*.tcl)
PKGDIR                = $(LIBDIR)/$(PKGNAME)
MANDIR                = share/man/man$(MANSEC)
DOCDIR                = doc

PKGIDX                = $(PKGDIR)/pkgIndex.tcl
PKGGENSCR             = scripts/tcl_pkggen.tcl

VERSION               = 3.0a1
VERSIONSCR            = scripts/update_version.sh
VERSIONSCRINSTALL     = scripts/install-version.sh

DOCDIRTCL             = $(DOCDIR)/$(PKGNAME)
DOCDIRLIB             = $(DOCDIR)/$(PKGNAME)-Lib
DOXYFILETCL           = doxy/tcl.doxyfile
DOXYFILELIB           = doxy/lib.doxyfile

BROWSER              ?= firefox

MANSEC                = 1
H2MBASENAMES         ?= $(filter-out icsng2icglue_filtersvndiff, $(PROGS))

SYNTAXDIR             = nagelfar
SYNTAXFILE_LIB        = $(SYNTAXDIR)/$(PKGNAME).nagelfar.db.tcl
SYNTAXFILE_CNSTR      = $(SYNTAXDIR)/$(PKGNAME)_construct.nagelfar.db.tcl
NAGELFAR_SYNTAXBUILD  = /usr/lib/nagelfar/syntaxbuild.tcl
SYNTAXGEN_LIB         = scripts/gen_nagelfar_db.tcl
SYNTAXGEN_CNSTR       = scripts/gen_nagelfar_db_construct.tcl

TEMPLATES             = templates
INSTDIR               = $(DESTDIR)$(PREFIX)

CMARK                 = cmark
HTML_HEAD             = html/html_head.html
HTML_FOOT             = html/html_foot.html
MD2HTMLDIR            = md2html
MDFILES               = $(wildcard doxy/*.md)
MD2HTMLFILES          = $(addprefix $(MD2HTMLDIR)/,$(addsuffix .html,$(basename $(MDFILES:doxy/%=%))))

LOCTOOL              ?= cloc
LOCSOURCES            = $(wildcard tcllib/*.tcl bin/* lib/*.c lib/*.h)
LOCTEMPLATES          = $(wildcard templates/*/*)
LOCEXTRA              = $(wildcard scripts/* vim/*/*.vim vim/*/*/*.vim) Makefile lib/Makefile

#-------------------------------------------------------
# Tcl Package
.PHONY: all everything prebuild syntaxdb docs man

all: prebuild
	@$(MAKE) $(PKGIDX)

everything: all syntaxdb docs man

prebuild $(CLIBSOURCES):
	@$(MAKE) -C $(CLIBDIR)

$(PKGIDX): $(TCLSOURCES) $(CLIBSOURCES) $(PKGGENSCR) | $(PKGDIR)
	rm -f $(PKGIDX)
	@for S in  $(CLIBSOURCES) $(TCLSOURCES); do  \
		echo "ln -sft $(PKGDIR) ../../$$S"; \
		ln -sft $(PKGDIR) ../../$$S; \
	done
	$(PKGGENSCR) $(PKGDIR)

#-------------------------------------------------------
# version number/header update
.PHONY: updateversion

updateversion:
	$(VERSIONSCR) $(VERSION)
	$(MAKE)
	$(MAKE) man


#-------------------------------------------------------
# documentation
.PHONY: doctcl doclib docs man docmd2html

doctcl: $(DOXYFILETCL) | $(DOCDIRTCL)
	-doxygen $(DOXYFILETCL)

doclib: $(DOXYFILELIB) | $(DOCDIRLIB)
	-doxygen $(DOXYFILELIB)

$(MD2HTMLDIR)/%.html: doxy/%.md | $(MD2HTMLDIR)
	@cat $(HTML_HEAD) > $@
	$(CMARK) $^ >> $@
	@cat $(HTML_FOOT) >> $@
	@sed -i -e 's/\.md\>/\.html/g' $@

docmd2html: $(MD2HTMLFILES)

docs: doctcl doclib

showdocs:
	$(BROWSER) $(DOCDIRLIB)/html/index.html $(DOCDIRTCL)/html/index.html > /dev/null 2> /dev/null &

$(MANDIR):
	-mkdir -p $(MANDIR)

$(MANDIR)/%.$(MANSEC): ./h2m/%.h2m ./bin/% $(PKGIDX) | $(MANDIR)
	-help2man -N -i ./h2m/$*.h2m ./bin/$* > $@
	-sed -i -e 's/ (INSTALLED-VERSION)//' $@

man: $(addprefix $(MANDIR)/,$(addsuffix .$(MANSEC),$(H2MBASENAMES)))


#-------------------------------------------------------
# syntax check
syntaxdb: $(SYNTAXFILE_LIB) $(SYNTAXFILE_CNSTR)

$(SYNTAXFILE_LIB): $(PKGIDX) | $(SYNTAXDIR)
	-NAGELFAR_SYNTAXBUILD=$(NAGELFAR_SYNTAXBUILD) $(SYNTAXGEN_LIB) $(SYNTAXFILE_LIB)

$(SYNTAXFILE_CNSTR): $(PKGIDX) | $(SYNTAXDIR)
	-NAGELFAR_SYNTAXBUILD=$(NAGELFAR_SYNTAXBUILD) $(SYNTAXGEN_CNSTR) $(SYNTAXFILE_CNSTR)

#-------------------------------------------------------
# debug helplers
.PHONY: shell memcheck

shell:
	@TCLLIBPATH=. eltclsh scripts/elinit.tcl

memcheck:
	TCLLIBPATH=. G_SLICE=always-malloc valgrind --leak-check=full eltclsh scripts/elinit.tcl


#-------------------------------------------------------
# install
.PHONY: install install_core install_templates install_doc install_helpers

install: install_core install_templates install_doc install_helpers

$(INSTDIR)/$(PKGDIR) $(INSTDIR)/bin $(INSTDIR)/share/icglue $(INSTDIR)/$(MANDIR):
	install -m755 -d $@

$(INSTDIR)/$(PKGDIR)/%.so: $(PKGDIR)/%.so | $(INSTDIR)/$(PKGDIR)
	install -m755 $< $@

$(INSTDIR)/$(PKGDIR)/%.tcl: $(PKGDIR)/%.tcl | $(INSTDIR)/$(PKGDIR)
	install -m644  $< $@

$(INSTDIR)/bin/%: bin/% | $(INSTDIR)/bin
	$(VERSIONSCRINSTALL) $< $@
ifeq ($(STATIC_SHEBANG),1)
	scripts/static_shebang $@
endif

install_core: \
    $(addprefix $(INSTDIR)/$(PKGDIR)/,$(notdir $(TCLSOURCES)) $(LIBNAME) pkgIndex.tcl) \
    $(addprefix $(INSTDIR)/bin/,$(PROGS)) \
    install_templates

install_templates: |  $(INSTDIR)/share/icglue
	cp -r $(TEMPLATES) $(INSTDIR)/share/icglue

$(INSTDIR)/$(MANDIR)/%.$(MANSEC): | $(INSTDIR)/$(MANDIR)
	install -m644 $(MANDIR)/$(notdir $@) $@
	sed -i -e 's#%DOCDIRTCL%#$(PREFIX)/share/icglue#' $@

install_doc: $(addprefix $(INSTDIR)/$(MANDIR)/,$(addsuffix .$(MANSEC),$(H2MBASENAMES))) | $(INSTDIR)/share/icglue
	@if [ -e $(DOCDIRTCL)/html ]; then \
		cp -r $(DOCDIRTCL)/html $(INSTDIR)/share/icglue ; \
	else  \
		echo "!! Documentation has not been build. !!" ; \
	fi

install_helpers: | $(INSTDIR)/share/icglue
	cp -r $(CURDIR)/vim $(INSTDIR)/share/icglue
	@if [ -e $(SYNTAXDIR) ]; then \
		cp -r $(SYNTAXDIR)  $(INSTDIR)/share/icglue ; \
	else \
		rm -r $(INSTDIR)/share/icglue/vim/syntax_checkers; \
		echo "!! Nagelfar syntaxdb has not been build !!" ; \
	fi

#-------------------------------------------------------
# LoC
.PHONY: loc locall

loc:
	@$(LOCTOOL) $(LOCSOURCES)

locall:
	@$(LOCTOOL) $(LOCSOURCES) $(LOCEXTRA) $(LOCTEMPLATES)

#-------------------------------------------------------
# directories
$(MD2HTMLDIR) $(PKGDIR) $(DOCDIR) $(DOCDIRTCL) $(DOCDIRLIB) $(SYNTAXDIR):
	mkdir -p $@

#-------------------------------------------------------
# cleanup targets
.PHONY: mrproper cleanall clean cleandoc cleansyntax

clean:
	rm -rf $(PKGDIR)
	rm -rf install

cleandoc:
	rm -rf $(DOCDIR)
	rm -rf $(MD2HTMLDIR)

cleansyntax:
	rm -rf $(SYNTAXDIR)

mrproper cleanall: clean cleandoc cleansyntax
	@$(MAKE) -C $(CLIBDIR) clean

