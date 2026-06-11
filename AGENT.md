# Agent Instructions

## Project

Android Sync transfers photos and videos from Android to macOS or another
HTTP/WebDAV-compatible destination on the local network.

## Repository Layout

- `android/` owns the dependency-free Android app, tests, build scripts, and
  browser UI prototype.
- `macos/` owns the native Swift receiver, media library, tests, resources, and
  packaging scripts.
- `docs/` contains shared project documentation.
- `releases/` contains versioned release artifacts and historical release notes.
- `dist/` and platform build directories are generated output.

Keep platform-specific code inside its owning platform directory. Do not
reintroduce Android or macOS implementation files at the repository root.

## Working Guidelines

- Read the relevant platform README before changing platform behavior.
- Follow existing code patterns and scripts instead of introducing a new build
  system or dependency without a clear need.
- Keep changes scoped to the request and do not overwrite unrelated local work.
- Do not manually edit generated build output or commit ignored artifacts.
- Update documentation when commands, layout, configuration, or user-visible
  behavior changes.

## Verification

Run the checks relevant to the files changed:

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh
```

Use the narrowest sufficient checks during development, then run the affected
platform's test suite before considering the work complete.
