# easy-installer — agent notes

- Host CLI/lib for installer projects + **Install in-place (add to PATH)**.
- Plugins live under `plugins/` (builtins) and `~/.config/easy-installer/plugins/` or PATH `easy-installer-plugin-<id>`.
- MSI/MSIX plugins call `msi-generator` (sibling repo `dev-centr/msi-generator`).
- Config/project files use KDL (`installer.kdl`).
- Shell: Win11 sparse package first; classic HKCU only when modern unavailable.
