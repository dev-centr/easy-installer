module easyinstaller.plugin;

import easyinstaller.project : InstallerProject;
import std.json : JSONValue;
import std.process : executeShell;
import std.file : exists;
import std.string : strip, splitLines;

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
    string detectGui(); /// path to designer exe, empty if none
    string installPlaybook(); /// playbook filename under playbooks/, empty if none
    ExtraField[] extrasSchema(); /// type-specific fields stored in installer.kdl extras {}
    string designerSource(const ref InstallerProject project, string outDir); /// emitted script/spec to open
    string build(const ref InstallerProject project, string outDir);
    string emitSources(const ref InstallerProject project, string outDir);
}

/// Field advertised by --describe / extrasSchema for type-specific overlay data.
struct ExtraField
{
    string key;
    string type; /// string, bool, int
    string defaultValue;
    string description;
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
    // Subprocess plugins: ibex-plugin-<id> on PATH — listed via --describe
    return list;
}

struct GuiInfo
{
    string pluginId;
    string name;
    string url;
    bool toolInstalled;
    bool guiInstalled;
    string detectDetail;
    string guiPath;
}

GuiInfo guiInfoFor(InstallerPlugin p)
{
    GuiInfo g;
    g.pluginId = p.id;
    g.name = p.guiName;
    g.url = p.guiInstallUrl;
    auto tool = p.detectTool;
    g.toolInstalled = tool.length > 0 && tool != "(built-in)";
    if (tool == "(built-in)")
        g.toolInstalled = true;
    g.guiPath = p.detectGui;
    g.guiInstalled = g.guiPath.length > 0;
    g.detectDetail = tool.length ? tool : p.guiDetectHint;
    return g;
}

string describeJson(InstallerPlugin p)
{
    JSONValue extras = JSONValue(JSONValue[].init);
    foreach (f; p.extrasSchema)
    {
        JSONValue e;
        e["key"] = f.key;
        e["type"] = f.type;
        e["default"] = f.defaultValue;
        e["description"] = f.description;
        extras.array ~= e;
    }
    JSONValue gui;
    gui["name"] = p.guiName;
    gui["url"] = p.guiInstallUrl;
    gui["path"] = p.detectGui;
    gui["hint"] = p.guiDetectHint;
    JSONValue j;
    j["id"] = p.id;
    j["displayName"] = p.displayName;
    j["targets"] = p.targets;
    j["canBuild"] = p.canBuild;
    j["tool"] = p.detectTool;
    j["gui"] = gui;
    j["installPlaybook"] = p.installPlaybook;
    j["extrasSchema"] = extras;
    return j.toPrettyString;
}

/// Emit sources then open the type-specific designer (file handoff, not form injection).
string openDesigner(InstallerPlugin p, const ref InstallerProject project, string outDir)
{
    auto msg = p.emitSources(project, outDir);
    auto src = p.designerSource(project, outDir);
    if (!src.length)
        return msg ~ "\nNo designer file for plugin " ~ p.id
            ~ " (built-in or compiler-only). Edit installer.kdl extras {} and rebuild.";
    if (!exists(src))
        return msg ~ "\nExpected designer file missing: " ~ src;
    return msg ~ "\n" ~ launchDesigner(p.detectGui, src);
}

string launchDesigner(string guiExe, string file)
{
    version (Windows)
    {
        auto r = guiExe.length
            ? executeShell(`start "" "` ~ guiExe ~ `" "` ~ file ~ `"`)
            : executeShell(`start "" "` ~ file ~ `"`);
        if (r.status != 0)
            return "Failed to open designer:\n" ~ r.output;
        return guiExe.length
            ? "Opened " ~ file ~ " with " ~ guiExe
            : "Opened " ~ file ~ " with the default app";
    }
    else version (OSX)
    {
        auto r = guiExe.length
            ? executeShell(`open -a "` ~ guiExe ~ `" "` ~ file ~ `"`)
            : executeShell(`open "` ~ file ~ `"`);
        if (r.status != 0)
            return "Failed to open designer:\n" ~ r.output;
        return "Opened " ~ file;
    }
    else
    {
        auto r = guiExe.length
            ? executeShell(`"` ~ guiExe ~ `" "` ~ file ~ `" >/dev/null 2>&1 &`)
            : executeShell(`xdg-open "` ~ file ~ `" >/dev/null 2>&1 &`);
        return "Attempted to open " ~ file;
    }
}

ExtraField[] noExtras()
{
    return ExtraField[].init;
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
