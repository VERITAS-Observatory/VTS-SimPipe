# CHANGELOG

All notable changes to the VTS-SimPipe project will be documented in this file.
Changes for upcoming releases can be found in the [docs/changes](docs/changes) directory.
Note that changes before release v2.2.0 are not documented here, but can be found in the
[GitHub repository](https://github.com/VERITAS-Observatory/VTS-SimPipe/releases).

This changelog is generated using [Towncrier](https://towncrier.readthedocs.io/).

<!-- towncrier release notes start -->

## [v2.2.0](https://github.com/VERITAS-Observatory/VTS-SimPipe/releases/tag/v2.2.0) - 2025-06-01

### New Feature

- Ensure VBF file consistency by running vbfReindex over all generated files. Ensure also that no corrupt file end up in the generated dataset. ([#52](https://github.com/VERITAS-Observatory/VTS-SimPipe/issues/52))

### Maintenance

- Introduction of towncrier-generated changelogs. Add CI running pre-commit. ([#53](https://github.com/VERITAS-Observatory/VTS-SimPipe/issues/53))
