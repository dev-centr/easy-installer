# Ibex — agent notes

- **Ibex** (Install Builder EXtension): host CLI for installer projects + **Install in-place (add to PATH)**.
- Binary: `ibex` (legacy `easy-installer` still dual-shipped on v0.2.x releases).
- Plugins live under `plugins/` (builtins) and `~/.config/ibex/plugins/` or PATH `ibex-plugin-<id>` (legacy easy-installer paths may still work).
- Common spec in `installer.kdl`; type-specific overlay in `extras { }`. Designer handoff is emit + open file, not GUI automation.
- Tool install: Scriptbook playbooks in `playbooks/`. Bootstrap Scriptbook with `scripts/install-scriptbook.ps1` / `.sh` (`ibex plugins install-scriptbook`). Do not vendor a second installer.
- MSI/MSIX plugins call `msi-generator` (sibling repo `dev-centr/msi-generator`).
- **Install Coordinator** (`dev-centr/install-coordinator`): thin `submit` stubs queue jobs; daemon serializes MSI and hosts UI at `http://127.0.0.1:17420/ui`.
- Config/project files use KDL (`installer.kdl`); CI profile uses SDL (`ci-runner.sdl`).
- Shell: Win11 sparse package first; classic HKCU only when modern unavailable.
- Registries: winget `DevCentr.Ibex`, Homebrew `dev-centr/tap/ibex`, Scoop manifest under `packaging/scoop/`.
