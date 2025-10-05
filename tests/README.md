# optwifi Test Suite

Automated testing framework for the optwifi package.

_Mostly written by Claude Code._

### Pros
- I did not have to write it.
    - Writing tests is no fun for me, which means if I don't get help from Claude, there are not going to be any tests.
- They seem to work and have already caught issues early during development, so it seems they are doing their job.

### Cons
- They are not thoroughly reviewed.
- The coverage may be incomplete.

## Running Tests

### Run all tests:
```bash
cd tests
sh test_runner.sh
```

### Run individual test suites:
```bash
sh tests/test_syntax.sh      # Syntax validation
sh tests/test_simple.sh       # Practical validation tests
ash tests/test_hex_decode.sh  # Hex decoding security tests (requires ash)
```

### Run from project root:
```bash
sh tests/test_runner.sh
```

## Test Structure

### test_syntax.sh
- Validates shell script syntax using `sh -n`
- Checks for correct shebang lines
- Ensures POSIX shell compatibility

### test_simple.sh
- Practical validation tests
- Tests function definitions
- Tests SSID validation logic
- Tests script sourcing and integration

### test_hex_decode.sh (requires ash)
- Security-focused hex decoding tests
- Tests `hex_to_ascii` function with ash shell (OpenWrt target)
- Validates UTF-8 multibyte character handling
- Tests input validation (odd length, non-hex characters)
- Security tests for code/data separation (no shell expansion)
- Tests special characters, spaces, and maximum length SSIDs

## Test Requirements

### Required for all tests:
- POSIX-compatible shell (sh)
- Basic utilities: grep, cut, mktemp

### Required for hex_decode tests:
- **ash shell** (busybox ash, OpenWrt default)
- Tests will only run if ash is available

### Shell Detection

The test runner automatically detects available shells:
- Prefers `ash` if available (OpenWrt-compatible)
- Falls back to `sh` otherwise
- Hex decoding tests are skipped if ash is not found

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

## Adding New Tests

1. Create test file in `tests/` directory
2. Follow naming convention: `test_*.sh`
3. Add to `test_runner.sh` if it should run automatically
4. Use test helpers for consistent output and assertions

Example:
```bash
#!/bin/sh
. "$(dirname "$0")/mocks/test_helpers.sh"

setup_test_env
# Your tests here
cleanup_test_env
```

## CI Integration

Tests can be run as part of package build:
```bash
make package/optwifi/compile V=s
```

Or run tests before building:
```bash
sh tests/test_runner.sh && make package/optwifi/compile
```
