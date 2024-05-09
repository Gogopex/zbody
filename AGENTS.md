# AGENT Instructions

This project is built with [Zig](https://ziglang.org/). Future Codex agents
should verify that the project still compiles and runs.

## Prerequisites
- `zig` 0.11 or newer must be installed.
- Network access may be required on the first build to fetch dependencies
  declared in `build.zig.zon`.

## Building
Use the following command to compile the project:

```bash
zig build
```

To run the native build after compilation:

```bash
zig build run
```

## Formatting
Ensure all Zig source files are formatted before committing:

```bash
zig fmt --check src/*.zig
```

There are currently no unit tests, but building successfully is treated as
the required programmatic check.
