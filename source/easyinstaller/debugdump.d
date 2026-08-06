module easyinstaller.debugdump;

import easyinstaller.paths : configRoot, ledgerPath;
import easyinstaller.plugin : allPlugins;
import easyinstaller.versioninfo : aboutLine;
import std.array : appender;
import std.conv : to;
import std.file : exists;
import std.process : environment;

string buildDebugDump()
{
    auto app = appender!string();
    app.put(aboutLine());
    app.put("\n");
    version (Windows)
        app.put("os: windows\n");
    else version (OSX)
        app.put("os: macos\n");
    else
        app.put("os: linux\n");
    app.put("configRoot: ");
    app.put(configRoot());
    app.put("\nledger: ");
    app.put(ledgerPath());
    app.put(exists(ledgerPath()) ? " (present)\n" : " (missing)\n");
    app.put("plugins:\n");
    foreach (p; allPlugins())
    {
        app.put("  - ");
        app.put(p.id);
        app.put(" tool=");
        auto t = p.detectTool();
        app.put(t.length ? t : "(none)");
        app.put("\n");
    }
    // Redacted env: only PATH length
    auto path = environment.get("PATH", "");
    app.put("PATH entries: ");
    import std.algorithm : count;
    version (Windows)
        app.put(to!string(path.count(';') + (path.length ? 1 : 0)));
    else
        app.put(to!string(path.count(':') + (path.length ? 1 : 0)));
    app.put("\n");
    return app.data;
}

void writeDebugDump(string path)
{
    import std.file : write;
    write(path, buildDebugDump());
}
