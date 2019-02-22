INKSCAPE        := inkscape
OUT_NAME        := logo.png
WIDTH           := 200
HEIGHT          := 200
ADDITIONAL_OPTS :=

all: $(OUT_NAME)

%.png: logo.svg
	$(INKSCAPE) --export-png=$@ $(ADDITIONAL_OPTS) --export-area-drawing --export-width=$(WIDTH) --export-height=$(HEIGHT) $<

clean:
	rm -f $(OUT_NAME)

.PHONY: all clean
