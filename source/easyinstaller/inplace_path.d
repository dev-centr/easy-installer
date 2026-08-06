module easyinstaller.inplace_path;

import easyinstaller.paths : ensureConfigDirs, ledgerPath;
import std.algorithm : canFind, filter, map;
import std.array : array, join, split;
import std.file : exists, readText, write;
import std.path : absolutePath, buildNormalizedPath;
import std.string : strip, splitLines, toLower, replace;
import std.stdio : writeln, stderr;

version (Windows)
{
    import std.process : executeShell;
}

struct LedgerEntry
{
    string path;
    string addedAt;
}

string[] loadLedger()
{
    ensureConfigDirs();
    auto p = ledgerPath();
    if (!exists(p))
        return [];
    return readText(p).splitLines.map!(l => l.strip).filter!(l => l.length > 0).array;
}

void saveLedger(string[] entries)
{
    ensureConfigDirs();
    write(ledgerPath(), entries.join("\n") ~ (entries.length ? "\n" : ""));
}

string normalizeDir(string dir)
{
    return buildNormalizedPath(absolutePath(dir));
}

version (Windows)
{
    private string readUserPath()
    {
        auto r = executeShell(
            `powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','User')"`);
        if (r.status != 0)
            return "";
        return r.output.strip;
    }

    private void writeUserPath(string value)
    {
        // Escape for PowerShell single-quoted string
        auto esc = value.replace("'", "''");
        auto r = executeShell(
            `powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('Path','`
            ~ esc ~ `','User')"`);
        if (r.status != 0)
            throw new Exception("Cannot write user Path: " ~ r.output);
    }

    private string[] splitPath(string pathEnv)
    {
        return pathEnv.split(";").map!(s => s.strip).filter!(s => s.length > 0).array;
    }

    private string joinPath(string[] parts)
    {
        return parts.join(";");
    }

    private bool pathEquals(string a, string b)
    {
        return buildNormalizedPath(a).toLower == buildNormalizedPath(b).toLower;
    }
}
else
{
    import std.path : expandTilde;
    import std.process : environment;

    private string profileSnippetPath()
    {
        return buildPath(configRootVia(), "path-snippet.sh");
    }

    private string configRootVia()
    {
        import easyinstaller.paths : configRoot;
        return configRoot();
    }

    private string[] readProfilePaths()
    {
        // Ledger is source of truth; also mirror into snippet sourced from shell rc.
        return loadLedger();
    }
}

string addInPlace(string dir)
{
    auto abs = normalizeDir(dir);
    if (!exists(abs))
        throw new Exception("Directory does not exist: " ~ abs);

    version (Windows)
    {
        auto current = splitPath(readUserPath());
        foreach (p; current)
        {
            if (pathEquals(p, abs))
                return "Already on user PATH: " ~ abs;
        }
        current ~= abs;
        writeUserPath(joinPath(current));
    }
    else
    {
        auto ledger = loadLedger();
        if (ledger.canFind(abs))
            return "Already registered: " ~ abs;
        // Write/update snippet and remind user to source it.
        ensureConfigDirs();
        import easyinstaller.paths : configRoot;
        import std.path : buildPath;
        auto snippet = buildPath(configRoot(), "path-snippet.sh");
        auto lines = loadLedger() ~ abs;
        string body = "# managed by easy-installer\n";
        foreach (p; lines)
            body ~= "export PATH=\"" ~ p ~ ":$PATH\"\n";
        write(snippet, body);
        // Also append to ~/.local/bin note — primary mechanism is PATH export snippet.
    }

    auto ledger = loadLedger();
    if (!ledger.canFind(abs))
    {
        ledger ~= abs;
        saveLedger(ledger);
    }

    version (Windows)
        return "Added to user PATH (in-place): " ~ abs
            ~ "\nOpen a new terminal for the change to take effect.";
    else
    {
        import easyinstaller.paths : configRoot;
        import std.path : buildPath;
        auto snippet = buildPath(configRoot(), "path-snippet.sh");
        return "Registered in-place PATH entry: " ~ abs
            ~ "\nAdd to your shell rc:  source \"" ~ snippet ~ "\"";
    }
}

string removeInPlace(string dir)
{
    auto abs = normalizeDir(dir);

    version (Windows)
    {
        auto current = splitPath(readUserPath());
        string[] kept;
        foreach (p; current)
        {
            if (!pathEquals(p, abs))
                kept ~= p;
        }
        writeUserPath(joinPath(kept));
    }
    else
    {
        import easyinstaller.paths : configRoot, ensureConfigDirs;
        import std.path : buildPath;
        ensureConfigDirs();
        auto snippet = buildPath(configRoot(), "path-snippet.sh");
        auto lines = loadLedger().filter!(p => p != abs).array;
        string body = "# managed by easy-installer\n";
        foreach (p; lines)
            body ~= "export PATH=\"" ~ p ~ ":$PATH\"\n";
        write(snippet, body);
    }

    auto ledger = loadLedger().filter!(p => normalizeDir(p) != abs
        && p != abs).array;
    // filter case-insensitively on Windows
    version (Windows)
    {
        ledger = loadLedger().filter!(p => !pathEquals(p, abs)).array;
    }
    saveLedger(ledger);
    return "Removed from PATH ledger (and user PATH where applicable): " ~ abs;
}

string listInPlace()
{
    auto entries = loadLedger();
    if (!entries.length)
        return "(no in-place PATH entries)";
    return entries.join("\n");
}
