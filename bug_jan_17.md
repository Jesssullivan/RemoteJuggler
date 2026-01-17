# Mason ldflags Bug Report

**Date**: 2026-01-17
**Reporter**: Jess Sullivan
**Chapel Version**: 2.7.0
**Mason Version**: 0.2.0
**Platform**: macOS (Darwin arm64)

---

## Summary

Mason cannot correctly pass `--ldflags` arguments containing spaces (such as `-framework Security -framework CoreFoundation`) through either:
1. The `compopts` field in `Mason.toml`
2. The `--` passthrough syntax at build time

The arguments are split on spaces, causing `-framework` to be interpreted as `-f` by the Chapel compiler.

---

## Reproduction Steps

### Method 1: compopts in Mason.toml

```toml
[brick]
name = "my_project"
version = "1.0.0"
# Attempting to pass ldflags with quoted arguments
compopts = "-M src --ldflags=\"-framework Security\""
```

**Result**: TOML parser error - cannot handle escaped quotes

### Method 2: Passthrough syntax

```bash
mason build -- '--ldflags=-framework Security -framework CoreFoundation'
```

**Result**:
```
Unrecognized flag: '-f' (use '-h' for help)
```

The string is split on spaces, so chpl receives:
- `--ldflags=-framework`
- `Security`
- `-framework`  ← interpreted as `-f`
- `CoreFoundation`

---

## Expected Behavior

The ldflags value should be passed intact to chpl:
```
chpl ... --ldflags="-framework Security -framework CoreFoundation" ...
```

This works correctly when invoked directly:
```bash
chpl --ldflags="-framework Security -framework CoreFoundation" src/main.chpl -o myapp
```

---

## Root Cause Analysis

### Source File: `tools/mason/MasonBuild.chpl`

#### Issue 1: String pushed without shell-aware splitting (line 205)

```chapel
proc compileSrc(..., compopts: list(string), ...) {
  var cmd: list(string);
  cmd.pushBack("chpl");
  cmd.pushBack(pathToProj);
  cmd.pushBack("-o " + moveTo);

  cmd.pushBack(compopts);  // <-- compopts pushed as-is
  ...
}
```

The `compopts` list is pushed directly to `cmd`. If `compopts` contains a single string like:
```
"-M src --ldflags=\"-framework Security\""
```

It's added as one element, but when the command is executed, shell splitting may occur incorrectly.

#### Issue 2: TOML parsing reads as single string (lines 378-380)

```chapel
proc getTomlCompopts(lock: borrowed Toml, ref compopts: list(string)) {
  if lock.pathExists('root.compopts') {
    const cmpFlags = lock["root"]!["compopts"]!.s;  // <-- reads as string
    compopts.pushBack(cmpFlags);  // <-- pushed as single element
  }
  ...
}
```

The compopts is read as a single string (`.s`) and pushed as one element. This works for simple flags but fails when the string contains values that need to stay quoted together.

#### Issue 3: Passthrough argument splitting (line 100)

```chapel
if passArgs.hasValue() {
  for val in passArgs.values() do compopts.pushBack(val);
}
```

Arguments passed via `--` are iterated and pushed individually. The shell has already split them on spaces before Mason sees them.

---

## Suggested Fix

### Option A: Shell-aware argument parsing

Add a function to properly parse shell-quoted arguments:

```chapel
proc parseShellArgs(argString: string): list(string) {
  // Parse respecting quotes:
  // '--ldflags="-framework Security"' -> ['--ldflags=-framework Security']
  ...
}
```

### Option B: Support array syntax for compopts

Allow compopts as a TOML array where each element is one argument:

```toml
[brick]
compopts = ["-M", "src", "--ldflags=-framework Security -framework CoreFoundation"]
```

This would require changing the TOML parsing:
```chapel
if lock["root"]!["compopts"]!.tag == fieldtype.array {
  for item in lock["root"]!["compopts"]!.A.values() {
    compopts.pushBack(item!.s);
  }
} else {
  compopts.pushBack(lock["root"]!["compopts"]!.s);
}
```

### Option C: Special handling for --ldflags

Recognize `--ldflags=` prefix and keep the entire value intact:

```chapel
proc processCompopt(opt: string): string {
  if opt.startsWith("--ldflags=") || opt.startsWith("--ccflags=") {
    // Keep the entire argument as-is, don't split
    return opt;
  }
  return opt;
}
```

---

## Workaround

Use a Makefile instead of `mason build` for macOS projects requiring framework linking:

```makefile
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  CHPL_LDFLAGS = --ldflags="-framework Security -framework CoreFoundation"
endif

build:
	chpl $(CHPL_FLAGS) $(CHPL_LDFLAGS) -o myapp src/main.chpl
```

---

## Impact

This bug affects any Chapel project on macOS that:
- Uses C FFI with Apple frameworks (Security, CoreFoundation, etc.)
- Needs to link against system libraries with `-framework` flags
- Wants to use Mason as the build tool

Projects affected must fall back to Makefiles or direct chpl invocation.

---

## Related Issues

- [Mason Improvements #7106](https://github.com/chapel-lang/chapel/issues/7106) - Epic tracking Mason enhancements
- Chapel Documentation: [C Interoperability](https://chapel-lang.org/docs/main/technotes/extern.html)

---

## Test Case

A minimal reproduction case:

```bash
# Create test project
mkdir mason-ldflags-test && cd mason-ldflags-test
mason new test_project
cd test_project

# Try to build with framework linking
mason build -- '--ldflags=-framework CoreFoundation'

# Expected: successful build
# Actual: "Unrecognized flag: '-f'"
```

---

## Environment

```
$ chpl --version
chpl version 2.7.0

$ mason --version
mason 0.2.0

$ uname -a
Darwin ... 25.2.0 Darwin Kernel Version 25.2.0 ... arm64
```

---

## Files

- Mason source: `~/git/chapel/tools/mason/MasonBuild.chpl`
- Affected project: `~/git/gitlab-switcher/` (RemoteJuggler)
- Working Makefile workaround: `~/git/gitlab-switcher/Makefile`
