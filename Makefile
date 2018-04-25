
LIBDIR     := lib
LIBSOURCES := $(LIBDIR)/binaries/icglue.so
TCLSOURCES := $(wildcard tcllib/*.tcl)
PKGDIR     := ICGlue

PKGIDX     := $(PKGDIR)/pkgIndex.tcl
PKGGENSCR  := pkggen/gen.tcl

all: prebuild
	@$(MAKE) $(PKGIDX)

prebuild $(LIBSOURCES):
	@$(MAKE) -C $(LIBDIR)

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

.PHONY: all prebuild clean cleanall
