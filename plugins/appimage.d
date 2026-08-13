module easyinstaller.plugins.appimage;

import easyinstaller.plugin;
import easyinstaller.project : InstallerProject, extra;
import std.file : exists, mkdirRecurse, write;
import std.path : buildPath;

final class AppImagePlugin : InstallerPlugin
{
    string id() { return "appimage"; }
    string displayName() { return "AppImage"; }
    string[] targets() { return ["linux"]; }
    bool canBuild() { return which("appimagetool").length > 0; }
    string detectTool() { return which("appimagetool"); }
    string guiName() { return "appimagetool"; }
    string guiInstallUrl() { return "https://github.com/AppImage/appimagetool"; }
    string guiDetectHint() { return "Install appimagetool on PATH"; }
    string detectGui() { return ""; }
    string installPlaybook() { return "install-appimagetool.cmk"; }
    ExtraField[] extrasSchema()
    {
        return [
            ExtraField("categories", "string", "Utility;", "Desktop Categories"),
        ];
    }
    string designerSource(const ref InstallerProject project, string outDir)
    {
        return buildPath(outDir, project.name ~ ".AppDir", project.name ~ ".desktop");
    }

    string emitSources(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        auto dir = buildPath(outDir, project.name ~ ".AppDir");
        mkdirRecurse(buildPath(dir, "usr", "bin"));
        auto categories = extra(project, "categories", "Utility;");
        write(buildPath(dir, "AppRun"), "#!/bin/sh\nexec \"$(dirname \"$0\")/usr/bin/"
            ~ project.name ~ "\" \"$@\"\n");
        write(buildPath(dir, project.name ~ ".desktop"),
            "[Desktop Entry]\nName=" ~ project.name ~ "\nExec=" ~ project.name
            ~ "\nType=Application\nCategories=" ~ categories ~ "\n");
        return "Wrote AppDir skeleton at " ~ dir
            ~ "\nCopy your binaries into usr/bin then build.";
    }

    string build(const ref InstallerProject project, string outDir)
    {
        auto msg = emitSources(project, outDir);
        auto tool = detectTool();
        if (!tool.length)
            return msg ~ "\nappimagetool not found — " ~ guiDetectHint();
        auto dir = buildPath(outDir, project.name ~ ".AppDir");
        auto outFile = buildPath(outDir, project.name ~ "-" ~ project.version_ ~ ".AppImage");
        import std.process : executeShell;
        auto r = executeShell(`"` ~ tool ~ `" "` ~ dir ~ `" "` ~ outFile ~ `"`);
        if (r.status != 0)
            return msg ~ "\nappimagetool failed:\n" ~ r.output;
        return msg ~ "\n" ~ r.output;
    }
}

shared static this()
{
    registerBuiltin(new AppImagePlugin());
}
