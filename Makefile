
LIBDIR     := lib
LIBSOURCES := $(LIBDIR)/icglue.so
TCLSOURCES := $(wildcard tcllib/*.tcl)
PKGDIR     := ICGlue

PKGIDX     := $(PKGDIR)/pkgIndex.tcl
PKGGENSCR  := pkggen/gen.tcl

.PHONY: all
all: $(PKGIDX)

prebuild:
	@$(MAKE) -C $(LIBDIR)

$(LIBSOURCES): prebuild

$(PKGIDX): $(TCLSOURCES) $(LIBSOURCES) $(PKGGENSCR) | $(PKGDIR)
	rm -f $(PKGIDX)
	cp $(LIBSOURCES) $(PKGDIR)
	cp $(TCLSOURCES) $(PKGDIR)
	$(PKGGENSCR) $(PKGDIR)

$(PKGDIR):
	mkdir -p $@

clean:
	rm -rf $(PKGDIR)

cleanall: clean
	@$(MAKE) -C $(LIBDIR) clean
