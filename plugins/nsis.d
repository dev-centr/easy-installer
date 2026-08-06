module easyinstaller.plugins.nsis;

import easyinstaller.plugin;
import easyinstaller.project : InstallerProject;
import std.file : exists, mkdirRecurse, write;
import std.path : buildPath, baseName;
import std.process : executeShell;
import std.string : replace;

final class NsisPlugin : InstallerPlugin
{
    string id() { return "nsis"; }
    string displayName() { return "NSIS"; }
    string[] targets() { return ["windows"]; }
    bool canBuild() { return which("makensis").length > 0; }
    string detectTool() { return which("makensis"); }
    string guiName() { return "NSIS / HM NIS Edit"; }
    string guiInstallUrl() { return "https://nsis.sourceforge.io/Download"; }
    string guiDetectHint() { return "Install NSIS so makensis is on PATH"; }

    string emitSources(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        auto nsi = buildPath(outDir, project.name ~ ".nsi");
        auto exeName = project.exe.length ? baseName(project.exe) : project.name ~ ".exe";
        auto script = `!define PRODUCT_NAME "` ~ project.name ~ `"
!define PRODUCT_VERSION "` ~ project.version_ ~ `"
!define PRODUCT_PUBLISHER "` ~ project.publisher ~ `"
Name "${PRODUCT_NAME}"
OutFile "` ~ project.name ~ `-setup.exe"
InstallDir "$PROGRAMFILES\\${PRODUCT_NAME}"
RequestExecutionLevel user
Page directory
Page instfiles
Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\\*.*"
` ~ (project.addToPath ? `  EnVar::AddValue "PATH" "$INSTDIR"
` : "") ~ `SectionEnd
`;
        write(nsi, script);
        return "Wrote " ~ nsi;
    }

    string build(const ref InstallerProject project, string outDir)
    {
        auto msg = emitSources(project, outDir);
        auto tool = detectTool();
        if (!tool.length)
            return msg ~ "\nmakensis not found — install NSIS or use plugins install-gui nsis";
        auto nsi = buildPath(outDir, project.name ~ ".nsi");
        auto r = executeShell(`"` ~ tool ~ `" "` ~ nsi ~ `"`);
        if (r.status != 0)
            return msg ~ "\nmakensis failed:\n" ~ r.output;
        return msg ~ "\n" ~ r.output;
    }
}

shared static this()
{
    registerBuiltin(new NsisPlugin());
}
