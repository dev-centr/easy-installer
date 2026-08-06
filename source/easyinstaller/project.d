module easyinstaller.project;

import std.algorithm : canFind, filter, map;
import std.array : array, join, split;
import std.conv : to;
import std.file : exists, mkdirRecurse, readText, write;
import std.path : absolutePath, baseName, buildPath, dirName;
import std.string : strip, splitLines, startsWith, indexOf, replace;

/// Installer project model (serialized as installer.kdl).
struct InstallerProject
{
    string name = "MyApp";
    string version_ = "1.0.0";
    string id = "com.example.myapp";
    string publisher = "Example";
    string description = "";
    string plugin = "portable-zip";
    string[] files; /// relative or absolute paths to include
    string exe; /// primary executable (optional)
    bool addToPath; /// ask installer to add install dir to PATH
    string rootDir; /// directory containing installer.kdl
}

string projectFilePath(string dir)
{
    return buildPath(dir, "installer.kdl");
}

InstallerProject defaultProject(string dir, string plugin = "portable-zip")
{
    InstallerProject p;
    p.rootDir = absolutePath(dir);
    p.name = baseName(p.rootDir);
    p.id = "local." ~ p.name;
    p.plugin = plugin.length ? plugin : "portable-zip";
    p.files = ["*"];
    return p;
}

string toKdl(const ref InstallerProject p)
{
    import std.string : replace;
    string esc(string s)
    {
        return s.replace(`\`, `\\`).replace(`"`, `\"`);
    }
    string[] lines;
    lines ~= `installer {`;
    lines ~= `    name "` ~ esc(p.name) ~ `"`;
    lines ~= `    version "` ~ esc(p.version_) ~ `"`;
    lines ~= `    id "` ~ esc(p.id) ~ `"`;
    lines ~= `    publisher "` ~ esc(p.publisher) ~ `"`;
    lines ~= `    description "` ~ esc(p.description) ~ `"`;
    lines ~= `    plugin "` ~ esc(p.plugin) ~ `"`;
    if (p.exe.length)
        lines ~= `    exe "` ~ esc(p.exe) ~ `"`;
    lines ~= `    add-to-path ` ~ (p.addToPath ? "true" : "false");
    lines ~= `    files {`;
    foreach (f; p.files)
        lines ~= `        file "` ~ esc(f) ~ `"`;
    lines ~= `    }`;
    lines ~= `}`;
    lines ~= ``;
    return lines.join("\n");
}

InstallerProject parseKdl(string text, string rootDir)
{
    InstallerProject p = defaultProject(rootDir);
    string section;
    foreach (raw; text.splitLines)
    {
        auto line = raw.strip;
        if (!line.length || line.startsWith("//") || line.startsWith("#"))
            continue;
        if (line.canFind("files {") || line == "files {")
        {
            section = "files";
            continue;
        }
        if (line == "}" || line == "};")
        {
            if (section == "files")
                section = "";
            continue;
        }
        if (section == "files")
        {
            auto v = extractQuoted(line);
            if (v.length)
                p.files ~= v;
            continue;
        }
        if (line.startsWith("name "))
            p.name = extractQuoted(line);
        else if (line.startsWith("version "))
            p.version_ = extractQuoted(line);
        else if (line.startsWith("id "))
            p.id = extractQuoted(line);
        else if (line.startsWith("publisher "))
            p.publisher = extractQuoted(line);
        else if (line.startsWith("description "))
            p.description = extractQuoted(line);
        else if (line.startsWith("plugin "))
            p.plugin = extractQuoted(line);
        else if (line.startsWith("exe "))
            p.exe = extractQuoted(line);
        else if (line.startsWith("add-to-path "))
            p.addToPath = line.canFind("true");
    }
    p.rootDir = absolutePath(rootDir);
    if (!p.files.length)
        p.files = ["*"];
    return p;
}

private string extractQuoted(string line)
{
    auto i = line.indexOf('"');
    if (i < 0)
    {
        auto parts = line.split(" ");
        return parts.length > 1 ? parts[$ - 1].strip : "";
    }
    auto rest = line[i + 1 .. $];
    auto j = rest.indexOf('"');
    if (j < 0)
        return rest;
    return rest[0 .. j];
}

InstallerProject loadProject(string dirOrFile)
{
    import std.file : isDir, isFile;
    string dir = dirOrFile;
    string file = projectFilePath(dir);
    if (exists(dirOrFile) && isFile(dirOrFile))
    {
        file = dirOrFile;
        dir = dirName(dirOrFile);
    }
    if (!exists(file))
        throw new Exception("No installer.kdl at " ~ file);
    return parseKdl(readText(file), dir);
}

void saveProject(const ref InstallerProject p)
{
    auto dir = p.rootDir;
    if (!exists(dir))
        mkdirRecurse(dir);
    write(projectFilePath(dir), toKdl(p));
}

string createNewProject(string dir, string plugin)
{
    auto p = defaultProject(dir, plugin);
    saveProject(p);
    auto readme = buildPath(dir, "INSTALLER.adoc");
    if (!exists(readme))
    {
        write(readme, "= Installer project\n\n"
            ~ "Edit `installer.kdl`, then run:\n\n"
            ~ "[source,bash]\n----\neasy-installer build .\n----\n");
    }
    return projectFilePath(dir);
}
