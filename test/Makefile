# directories
TEST_DIR = tests
RES_DIR  = results

RUN_DIR  = run
LOG_DIR  = log

# tests/results
TESTS    = $(notdir $(wildcard $(TEST_DIR)/*))
RESULTS  = $(foreach t, $(TESTS), $(RES_DIR)/$(t).result)

# rules
all: summary

$(RES_DIR)/%.result:
	@./runtest --clean-after $*

summary: $(RESULTS)
	@echo "=== SUMMARY ==="
	@./summary $(TESTS)

.PHONY: summary

# clean
clean:
	@rm -rf $(RUN_DIR) $(LOG_DIR) $(RES_DIR)
.PHONY: clean
