.PHONY: check

# Recursion guard: when make check is invoked from within a test that make check
# itself runs, skip tests that call 'make check' to prevent infinite recursion.
# The recipe exports REPOLENS_MAKE_CHECK=1 for child processes; on recursive
# invocation make sees the env var at parse time and sets _SKIP_META accordingly.
_SKIP_META := $(if $(REPOLENS_MAKE_CHECK),1,)

check:
	@export REPOLENS_MAKE_CHECK=1; \
	suites_run=0; suites_failed=0; \
	for f in $$(find tests -maxdepth 1 -name 'test_*.sh' -type f | sort); do \
	  if [ "$(_SKIP_META)" = "1" ] && grep -q '&& make check' "$$f" 2>/dev/null; then \
	    continue; \
	  fi; \
	  output=$$(bash "$$f" 2>&1); rc=$$?; \
	  result_line=$$(echo "$$output" | grep 'Results:' | tail -1); \
	  if [ "$$rc" -eq 0 ]; then \
	    echo "PASSED: $$f — $$result_line"; \
	  else \
	    echo "FAILED: $$f — $$result_line"; \
	    echo "$$output" | grep -E '^\s*FAIL:' || true; \
	    suites_failed=$$((suites_failed + 1)); \
	  fi; \
	  suites_run=$$((suites_run + 1)); \
	done; \
	echo ""; \
	echo "Results: $$suites_run suites run, $$suites_failed failed"; \
	if [ "$$suites_failed" -gt 0 ]; then exit 1; fi
