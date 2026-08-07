module easyinstaller.ci_profile;

import std.algorithm : canFind;
import std.array : join;
import std.file : exists, readText, write;
import std.path : absolutePath, buildPath;
import std.string : strip, splitLines, startsWith, indexOf, replace, toLower;

/// Supported CI runners (emitter ids).
immutable string[] knownRunners = [
    "github-actions",
    "gitlab-ci",
    "azure-pipelines",
    "jenkins",
    "circleci",
    "bitbucket-pipelines",
];

/// SDLang profile beside installer.kdl — drives emit-ci only.
struct CiRunnerProfile
{
    string runner = "github-actions";
    string plugin = "portable-zip";
    string tagPattern = "v*";
    bool windows = true;
    string ibex = "0.2.0"; /// Pin for CLI download in emitted CI (alias: easyInstaller)
    string msiGenerator = "0.2.0";
    bool uploadRelease = true;
    string rootDir;

    /// Transitional alias for older field name.
    @property string easyInstaller() const { return ibex; }
    @property void easyInstaller(string v) { ibex = v; }
}

string ciProfilePath(string dir)
{
    return buildPath(dir, "ci-runner.sdl");
}

CiRunnerProfile defaultCiProfile(string dir, string runner = "github-actions", string plugin = "portable-zip")
{
    CiRunnerProfile p;
    p.rootDir = absolutePath(dir);
    p.runner = runner.length ? runner : "github-actions";
    p.plugin = plugin.length ? plugin : "portable-zip";
    return p;
}

void validateRunner(string runner)
{
    if (!knownRunners.canFind(runner))
        throw new Exception("Unknown CI runner \"" ~ runner ~ "\". Supported: " ~ knownRunners.join(", "));
}

string toSdl(const ref CiRunnerProfile p)
{
    string esc(string s)
    {
        return s.replace(`\`, `\\`).replace(`"`, `\"`);
    }
    string[] lines;
    lines ~= `ciRunner {`;
    lines ~= `    runner "` ~ esc(p.runner) ~ `"`;
    lines ~= `    plugin "` ~ esc(p.plugin) ~ `"`;
    lines ~= `    on tags "` ~ esc(p.tagPattern) ~ `"`;
    lines ~= `    windows ` ~ (p.windows ? "true" : "false");
    lines ~= `    ibex "` ~ esc(p.ibex) ~ `"`;
    lines ~= `    msiGenerator "` ~ esc(p.msiGenerator) ~ `"`;
    lines ~= `    uploadRelease ` ~ (p.uploadRelease ? "true" : "false");
    lines ~= `}`;
    lines ~= ``;
    return lines.join("\n");
}

private string extractQuoted(string line)
{
    import std.array : split;
    auto i = line.indexOf('"');
    if (i < 0)
    {
        auto toks = line.strip.split(" ");
        return toks.length > 1 ? toks[$ - 1].strip : "";
    }
    auto rest = line[i + 1 .. $];
    auto j = rest.indexOf('"');
    if (j < 0)
        return rest;
    return rest[0 .. j];
}

CiRunnerProfile parseSdl(string text, string rootDir)
{
    auto p = defaultCiProfile(rootDir);
    foreach (raw; text.splitLines)
    {
        auto line = raw.strip;
        if (!line.length || line.startsWith("//") || line.startsWith("#") || line.startsWith("/*"))
            continue;
        if (line.startsWith("runner "))
            p.runner = extractQuoted(line);
        else if (line.startsWith("plugin "))
            p.plugin = extractQuoted(line);
        else if (line.startsWith("on tags ") || line.startsWith("on-tags ") || line.startsWith("tags "))
            p.tagPattern = extractQuoted(line);
        else if (line.startsWith("windows "))
            p.windows = line.canFind("true");
        else if (line.startsWith("ibex ") || line.startsWith("easyInstaller ")
            || line.startsWith("easy-installer "))
            p.ibex = extractQuoted(line);
        else if (line.startsWith("msiGenerator ") || line.startsWith("msi-generator "))
            p.msiGenerator = extractQuoted(line);
        else if (line.startsWith("uploadRelease ") || line.startsWith("upload-release "))
            p.uploadRelease = line.canFind("true");
    }
    p.rootDir = absolutePath(rootDir);
    validateRunner(p.runner);
    return p;
}

CiRunnerProfile loadCiProfile(string dirOrFile)
{
    import std.file : isFile;
    import std.path : dirName;
    string dir = dirOrFile;
    string file = ciProfilePath(dir);
    if (exists(dirOrFile) && isFile(dirOrFile))
    {
        file = dirOrFile;
        dir = dirName(dirOrFile);
    }
    if (!exists(file))
        throw new Exception("No ci-runner.sdl at " ~ file);
    return parseSdl(readText(file), dir);
}

void saveCiProfile(const ref CiRunnerProfile p)
{
    validateRunner(p.runner);
    import std.file : mkdirRecurse;
    if (!exists(p.rootDir))
        mkdirRecurse(p.rootDir);
    write(ciProfilePath(p.rootDir), toSdl(p));
}
