OUT_NAME        := logo.png
WIDTH           := 200
HEIGHT          := 200
ADDITIONAL_OPTS :=

all: $(OUT_NAME)

%.png: %.svg
	rsvg-convert -f png -w $(WIDTH) -h $(HEIGHT) $(ADDITIONAL_OPTS) $< -o $@

clean:
	rm -f $(OUT_NAME)

.PHONY: all clean
