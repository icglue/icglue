INKSCAPE        := inkscape
OUT_NAME        := logo.png
WIDTH           := 200
HEIGHT          := 200
ADDITIONAL_OPTS :=

INKSCAPE_VERSION_MAIN = $(shell inkscape --version 2>/dev/null | grep -e 'Inkscape\s*[0-9.]\+' | sed -e 's#^.*Inkscape\s*\([0-9]\+\)\..*$$#\1#')
ifeq ($(INKSCAPE_VERSION_MAIN),0)
  INKSCAPE_EXPORT_PNG_OPT = --export-png
else
  INKSCAPE_EXPORT_PNG_OPT = --export-filename
endif

all: $(OUT_NAME)

%.png: logo.svg
	$(INKSCAPE) $(INKSCAPE_EXPORT_PNG_OPT)=$@ $(ADDITIONAL_OPTS) --export-area-drawing --export-width=$(WIDTH) --export-height=$(HEIGHT) $<

clean:
	rm -f $(OUT_NAME)

.PHONY: all clean
