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
            return buildPath(local, "easy-installer");
        return buildPath(expandTilde("~"), "AppData", "Local", "easy-installer");
    }
    else
    {
        auto xdg = environment.get("XDG_CONFIG_HOME", "");
        if (xdg.length)
            return buildPath(xdg, "easy-installer");
        return buildPath(expandTilde("~"), ".config", "easy-installer");
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
