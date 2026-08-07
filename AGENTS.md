# Ibex — agent notes

- **Ibex** (Install Builder EXtension): host CLI for installer projects + **Install in-place (add to PATH)**.
- Binary: `ibex` (legacy `easy-installer` still dual-shipped on v0.2.x releases).
- Plugins live under `plugins/` (builtins) and `~/.config/ibex/plugins/` or PATH `ibex-plugin-<id>` (legacy easy-installer paths may still work).
- MSI/MSIX plugins call `msi-generator` (sibling repo `dev-centr/msi-generator`).
- Config/project files use KDL (`installer.kdl`); CI profile uses SDL (`ci-runner.sdl`).
- Shell: Win11 sparse package first; classic HKCU only when modern unavailable.
- Registries: winget `DevCentr.Ibex`, Homebrew `dev-centr/tap/ibex`, Scoop manifest under `packaging/scoop/`.
