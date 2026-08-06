import easyinstaller.debugdump;
import easyinstaller.inplace_path;
import easyinstaller.plugin;
import easyinstaller.project;
import easyinstaller.shell_hooks;
import easyinstaller.versioninfo;
import std.file : mkdirRecurse, exists;
import std.path : buildPath, absolutePath;
import std.stdio : writeln, stderr;
import std.string : toLower;

// Pull in builtin plugins
import easyinstaller.plugins.portable_zip;
import easyinstaller.plugins.nsis;
import easyinstaller.plugins.inno;
import easyinstaller.plugins.msi_msix;
import easyinstaller.plugins.appimage;

int main(string[] args)
{
    if (args.length < 2)
        return usage();

    auto cmd = args[1].toLower;
    try
    {
        switch (cmd)
        {
        case "--version":
        case "version":
            writeln(aboutLine());
            return 0;
        case "debug-dump":
            if (args.length >= 3)
            {
                writeDebugDump(args[2]);
                writeln("Wrote ", args[2]);
            }
            else
                writeln(buildDebugDump());
            return 0;
        case "inplace-path":
            return cmdInplace(args[2 .. $]);
        case "new-project":
            return cmdNewProject(args[2 .. $]);
        case "build":
            return cmdBuild(args[2 .. $]);
        case "plugins":
            return cmdPlugins(args[2 .. $]);
        case "shell":
            return cmdShell(args[2 .. $]);
        case "help":
        case "--help":
        case "-h":
            return usage();
        default:
            stderr.writeln("Unknown command: ", args[1]);
            return usage();
        }
    }
    catch (Exception e)
    {
        stderr.writeln("error: ", e.msg);
        return 1;
    }
}

int usage()
{
    writeln(aboutLine());
    writeln(`
Usage:
  easy-installer inplace-path add|remove|list [dir]
  easy-installer new-project <dir> [--plugin=<id>]
  easy-installer build <dir> [--plugin=<id>]
  easy-installer plugins list|info <id>|install-gui <id>
  easy-installer shell install|uninstall
  easy-installer --version
  easy-installer debug-dump [file]
`);
    return 0;
}

int cmdInplace(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("inplace-path requires add|remove|list");
        return 1;
    }
    auto sub = args[0].toLower;
    if (sub == "list")
    {
        writeln(listInPlace());
        return 0;
    }
    if (args.length < 2)
    {
        stderr.writeln("directory required");
        return 1;
    }
    if (sub == "add")
        writeln(addInPlace(args[1]));
    else if (sub == "remove")
        writeln(removeInPlace(args[1]));
    else
    {
        stderr.writeln("unknown subcommand: ", sub);
        return 1;
    }
    return 0;
}

int cmdNewProject(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("directory required");
        return 1;
    }
    string dir = args[0];
    string plugin = "portable-zip";
    foreach (a; args[1 .. $])
    {
        if (a.length > 9 && a[0 .. 9] == "--plugin=")
            plugin = a[9 .. $];
    }
    auto path = createNewProject(absolutePath(dir), plugin);
    writeln("Created ", path);
    return 0;
}

int cmdBuild(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("project directory required");
        return 1;
    }
    auto project = loadProject(args[0]);
    foreach (a; args[1 .. $])
    {
        if (a.length > 9 && a[0 .. 9] == "--plugin=")
            project.plugin = a[9 .. $];
    }
    auto plug = findPlugin(project.plugin);
    if (plug is null)
    {
        stderr.writeln("unknown plugin: ", project.plugin);
        return 1;
    }
    auto outDir = buildPath(project.rootDir, "dist");
    if (!exists(outDir))
        mkdirRecurse(outDir);
    writeln(plug.build(project, outDir));
    return 0;
}

int cmdPlugins(string[] args)
{
    if (!args.length || args[0].toLower == "list")
    {
        foreach (p; allPlugins())
        {
            auto tool = p.detectTool();
            writeln(p.id, "\t", p.displayName(), "\t",
                tool.length ? "tool=" ~ tool : "tool=missing",
                p.guiName.length ? "\tgui=" ~ p.guiName : "");
        }
        return 0;
    }
    auto sub = args[0].toLower;
    if (args.length < 2)
    {
        stderr.writeln("plugin id required");
        return 1;
    }
    auto p = findPlugin(args[1]);
    if (p is null)
    {
        stderr.writeln("unknown plugin: ", args[1]);
        return 1;
    }
    if (sub == "info")
    {
        auto g = guiInfoFor(p);
        writeln("id: ", p.id);
        writeln("name: ", p.displayName);
        writeln("targets: ", p.targets);
        writeln("canBuild: ", p.canBuild);
        writeln("tool: ", p.detectTool.length ? p.detectTool : "(none)");
        writeln("gui: ", g.name.length ? g.name : "(none)");
        writeln("guiUrl: ", g.url);
        writeln("guiInstalled: ", g.installed);
        writeln("hint: ", g.detectDetail);
        return 0;
    }
    if (sub == "install-gui")
    {
        if (!p.guiInstallUrl.length)
        {
            writeln("No GUI/install URL for ", p.id);
            return 0;
        }
        writeln(openUrl(p.guiInstallUrl));
        return 0;
    }
    stderr.writeln("unknown plugins subcommand: ", sub);
    return 1;
}

int cmdShell(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("shell install|uninstall");
        return 1;
    }
    auto sub = args[0].toLower;
    if (sub == "install")
        writeln(installShell());
    else if (sub == "uninstall")
        writeln(uninstallShell());
    else
    {
        stderr.writeln("unknown: ", sub);
        return 1;
    }
    return 0;
}
