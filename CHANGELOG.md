# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.2

### Fixed

- Timeout errors raised by the underlying `Restrainer` Redis calls no longer trigger the long running retry; only timeout errors raised by the block itself do. Previously a matching error raised while releasing the throttle could re-run a block that had already succeeded.
- Timeout errors that are not `StandardError` subclasses now correctly trigger the long running retry.
- `limit: 0` now means no executions are allowed (matching `Restrainer` semantics) instead of silently meaning unlimited. Use `limit: nil` (the default) for no limit.
- The orphaned lock expiration on the underlying restrainers is now derived from `long_running_timeout` so that blocks legitimately running longer than 60 seconds no longer allow the concurrency limits to be exceeded.

## 1.0.1

### Added

- Methods to expose the pool limits, timeouts and current in use sizes.

## 1.0.0

### Added

- Initial release.
