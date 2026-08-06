module easyinstaller.plugin;

import easyinstaller.project : InstallerProject;
import std.algorithm : filter, map, sort;
import std.array : array, appender;
import std.process : executeShell, environment;
import std.path : buildPath;
import std.file : exists, dirEntries, SpanMode;
import std.string : strip, startsWith, splitLines;

/// Plugin metadata + operations.
interface InstallerPlugin
{
    string id();
    string displayName();
    string[] targets(); /// "windows", "macos", "linux", or "all"
    bool canBuild();
    string detectTool(); /// empty if not found / not required
    string guiName(); /// optional designer GUI name
    string guiInstallUrl();
    string guiDetectHint(); /// how we detect the GUI
    string build(const ref InstallerProject project, string outDir);
    string emitSources(const ref InstallerProject project, string outDir);
}

InstallerPlugin[] g_builtinPlugins;

void registerBuiltin(InstallerPlugin p)
{
    g_builtinPlugins ~= p;
}

InstallerPlugin findPlugin(string id)
{
    foreach (p; allPlugins())
        if (p.id == id)
            return p;
    return null;
}

InstallerPlugin[] allPlugins()
{
    auto list = g_builtinPlugins.dup;
    // Subprocess plugins: easy-installer-plugin-<id> on PATH — listed via --describe
    // Discovery of external is best-effort at list time.
    return list;
}

struct GuiInfo
{
    string pluginId;
    string name;
    string url;
    bool installed;
    string detectDetail;
}

GuiInfo guiInfoFor(InstallerPlugin p)
{
    GuiInfo g;
    g.pluginId = p.id;
    g.name = p.guiName;
    g.url = p.guiInstallUrl;
    auto tool = p.detectTool;
    g.installed = tool.length > 0;
    g.detectDetail = tool.length ? tool : p.guiDetectHint;
    return g;
}

string which(string name)
{
    version (Windows)
    {
        auto r = executeShell(`where ` ~ name ~ ` 2>NUL`);
        if (r.status == 0)
        {
            auto lines = r.output.splitLines;
            if (lines.length)
                return lines[0].strip;
        }
    }
    else
    {
        auto r = executeShell(`command -v ` ~ name);
        if (r.status == 0)
            return r.output.strip;
    }
    return "";
}

string openUrl(string url)
{
    version (Windows)
    {
        auto r = executeShell(`start "" "` ~ url ~ `"`);
        return r.status == 0 ? "Opened " ~ url : r.output;
    }
    else version (OSX)
    {
        auto r = executeShell(`open "` ~ url ~ `"`);
        return r.status == 0 ? "Opened " ~ url : r.output;
    }
    else
    {
        auto r = executeShell(`xdg-open "` ~ url ~ `" >/dev/null 2>&1 &`);
        return "Attempted to open " ~ url;
    }
}
