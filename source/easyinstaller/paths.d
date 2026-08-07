module easyinstaller.paths;

import std.file : exists, mkdirRecurse;
import std.path : buildPath, expandTilde;
import std.process : environment;

/// Config / ledger root (per user).
string configRoot()
{
    version (Windows)
    {
        auto local = environment.get("LOCALAPPDATA", "");
        if (local.length)
        {
            auto ibex = buildPath(local, "ibex");
            auto legacy = buildPath(local, "easy-installer");
            if (exists(ibex) || !exists(legacy))
                return ibex;
            return legacy;
        }
        return buildPath(expandTilde("~"), "AppData", "Local", "ibex");
    }
    else
    {
        auto xdg = environment.get("XDG_CONFIG_HOME", "");
        auto base = xdg.length ? xdg : buildPath(expandTilde("~"), ".config");
        auto ibex = buildPath(base, "ibex");
        auto legacy = buildPath(base, "easy-installer");
        if (exists(ibex) || !exists(legacy))
            return ibex;
        return legacy;
    }
}

string ledgerPath()
{
    return buildPath(configRoot(), "inplace-path.ledger");
}

string pluginDirUser()
{
    return buildPath(configRoot(), "plugins");
}

void ensureConfigDirs()
{
    auto root = configRoot();
    if (!exists(root))
        mkdirRecurse(root);
    auto plugins = pluginDirUser();
    if (!exists(plugins))
        mkdirRecurse(plugins);
}
