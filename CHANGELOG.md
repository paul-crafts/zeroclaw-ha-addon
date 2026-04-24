# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-04-24

### Added
- **HA Ingress Support**: Access the UI directly from the Home Assistant sidebar.
- **Built-in Web Terminal**: Integrated `ttyd` for direct shell access and onboarding.
- **Premium Landing Page**: New entry point for the Ingress interface.
- **Service Supervision**: Nginx, ZeroClaw, and ttyd are now monitored and automatically restarted on failure.
- **Nginx Reverse Proxy**: Secure internal routing for addon services.
- **Unit Testing**: Mock-based test suite for initialization logic.
- **CI Workflow**: GitHub Actions for automated linting and validation.
- **License**: MIT License added.
- **Enhanced Documentation**: Redesigned README and detailed DOCS.md.

### Changed
- Refactored `run.sh` for better signal handling and process management.
- Updated `Dockerfile` to include all necessary runtime dependencies.

## [0.2.3] - 2026-04-20

### Fixed
- Improved architecture detection in Dockerfile.
- Minor bug fixes in daemon initialization.
