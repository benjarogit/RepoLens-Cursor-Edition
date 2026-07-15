.PHONY: check

# Recursion guard: meta-tests that spawn `make check` / `tests/run-all.sh` must
# always be skipped here (same criterion as tests/run-all.sh). Relying only on
# parse-time $(REPOLENS_MAKE_CHECK) left the *outer* invocation unprotected and
# caused nested full-suite wedges via tests/test_issue6_test27_fix.sh.
check:
	@export REPOLENS_MAKE_CHECK=1; \
	_SKIP_META=1; \
	suites_run=0; suites_failed=0; \
	for f in $$(find tests -maxdepth 1 -name 'test_*.sh' -type f | sort); do \
	  if [ "$$_SKIP_META" = "1" ] && grep -q '&& make check' "$$f" 2>/dev/null; then \
	    continue; \
	  fi; \
	  if [ "$$_SKIP_META" = "1" ] && grep -q 'tests/run-all\.sh' "$$f" 2>/dev/null; then \
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
