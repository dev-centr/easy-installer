module easyinstaller.plugins.nsis;

import easyinstaller.plugin;
import easyinstaller.project : InstallerProject, extra;
import std.file : exists, mkdirRecurse, write;
import std.path : buildPath, dirName;
import std.process : executeShell;

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
    string installPlaybook() { return "install-nsis.cmk"; }
    ExtraField[] extrasSchema()
    {
        return [
            ExtraField("installDir", "string", `$PROGRAMFILES\\${PRODUCT_NAME}`, "NSIS InstallDir"),
            ExtraField("requestExecutionLevel", "string", "user", "user or admin"),
            ExtraField("outFile", "string", "", "OutFile name (default: <name>-setup.exe)"),
        ];
    }
    string detectGui()
    {
        auto mk = detectTool();
        if (mk.length)
        {
            auto nsis = buildPath(dirName(mk), "NSIS.exe");
            if (exists(nsis))
                return nsis;
        }
        version (Windows)
        {
            foreach (c; [
                `C:\Program Files (x86)\NSIS\NSIS.exe`,
                `C:\Program Files\NSIS\NSIS.exe`,
            ])
                if (exists(c))
                    return c;
        }
        return "";
    }
    string designerSource(const ref InstallerProject project, string outDir)
    {
        return buildPath(outDir, project.name ~ ".nsi");
    }

    string emitSources(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        auto nsi = buildPath(outDir, project.name ~ ".nsi");
        auto outFile = extra(project, "outFile", project.name ~ "-setup.exe");
        auto installDir = extra(project, "installDir", `$PROGRAMFILES\\${PRODUCT_NAME}`);
        auto execLevel = extra(project, "requestExecutionLevel", "user");
        auto script = `!define PRODUCT_NAME "` ~ project.name ~ `"
!define PRODUCT_VERSION "` ~ project.version_ ~ `"
!define PRODUCT_PUBLISHER "` ~ project.publisher ~ `"
Name "${PRODUCT_NAME}"
OutFile "` ~ outFile ~ `"
InstallDir "` ~ installDir ~ `"
RequestExecutionLevel ` ~ execLevel ~ `
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
            return msg ~ "\nmakensis not found — run: ibex plugins install-tool nsis";
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
