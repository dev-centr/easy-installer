module easyinstaller.inplace_path;

import easyinstaller.paths : ensureConfigDirs, ledgerPath, configRoot;
import std.algorithm : canFind, filter, map;
import std.array : array, join, split;
import std.file : exists, readText, write;
import std.path : absolutePath, buildNormalizedPath, buildPath;
import std.string : strip, splitLines, toLower, replace;

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

private string pathSnippetFile()
{
    return buildPath(configRoot(), "path-snippet.sh");
}

private void writeUnixSnippet(string[] paths)
{
    ensureConfigDirs();
    string body = "# managed by ibex\n";
    foreach (p; paths)
        body ~= "export PATH=\"" ~ p ~ ":$PATH\"\n";
    write(pathSnippetFile(), body);
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
        auto existing = loadLedger();
        if (existing.canFind(abs))
            return "Already registered: " ~ abs;
        writeUnixSnippet(existing ~ abs);
    }

    auto entries = loadLedger();
    if (!entries.canFind(abs))
    {
        entries ~= abs;
        saveLedger(entries);
    }

    version (Windows)
        return "Added to user PATH (in-place): " ~ abs
            ~ "\nOpen a new terminal for the change to take effect.";
    else
        return "Registered in-place PATH entry: " ~ abs
            ~ "\nAdd to your shell rc:  source \"" ~ pathSnippetFile() ~ "\"";
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
        auto entries = loadLedger().filter!(p => !pathEquals(p, abs)).array;
        saveLedger(entries);
    }
    else
    {
        auto entries = loadLedger().filter!(p => p != abs && normalizeDir(p) != abs).array;
        writeUnixSnippet(entries);
        saveLedger(entries);
    }
    return "Removed from PATH ledger (and user PATH where applicable): " ~ abs;
}

string listInPlace()
{
    auto entries = loadLedger();
    if (!entries.length)
        return "(no in-place PATH entries)";
    return entries.join("\n");
}
