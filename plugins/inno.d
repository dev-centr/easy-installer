module easyinstaller.plugins.inno;

import easyinstaller.plugin;
import easyinstaller.project : InstallerProject, extra, extraFlag;
import std.file : exists, mkdirRecurse, write;
import std.path : buildPath, dirName;
import std.process : executeShell;

final class InnoPlugin : InstallerPlugin
{
    string id() { return "inno"; }
    string displayName() { return "Inno Setup"; }
    string[] targets() { return ["windows"]; }
    bool canBuild() { return detectTool().length > 0; }

    string detectTool()
    {
        auto w = which("ISCC");
        if (w.length)
            return w;
        version (Windows)
        {
            import std.path : expandTilde;
            string[] candidates = [
                `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`,
                `C:\Program Files\Inno Setup 6\ISCC.exe`,
            ];
            foreach (c; candidates)
                if (exists(c))
                    return c;
        }
        return "";
    }

    string guiName() { return "Inno Setup IDE"; }
    string guiInstallUrl() { return "https://jrsoftware.org/isdl.php"; }
    string guiDetectHint() { return "Install Inno Setup 6 (ISCC.exe)"; }
    string installPlaybook() { return "install-inno.cmk"; }
    ExtraField[] extrasSchema()
    {
        return [
            ExtraField("compression", "string", "lzma", "Inno Compression (lzma, zip, none)"),
            ExtraField("solid", "bool", "true", "SolidCompression"),
            ExtraField("outputBaseFilename", "string", "", "OutputBaseFilename (default: <name>-setup)"),
        ];
    }
    string detectGui()
    {
        auto iscc = detectTool();
        if (iscc.length)
        {
            auto compil = buildPath(dirName(iscc), "Compil32.exe");
            if (exists(compil))
                return compil;
        }
        version (Windows)
        {
            foreach (c; [
                `C:\Program Files (x86)\Inno Setup 6\Compil32.exe`,
                `C:\Program Files\Inno Setup 6\Compil32.exe`,
            ])
                if (exists(c))
                    return c;
        }
        return "";
    }
    string designerSource(const ref InstallerProject project, string outDir)
    {
        return buildPath(outDir, project.name ~ ".iss");
    }

    string emitSources(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        auto iss = buildPath(outDir, project.name ~ ".iss");
        auto pathFlag = project.addToPath
            ? "ChangesEnvironment=yes\n"
            : "";
        auto compression = extra(project, "compression", "lzma");
        auto solid = extraFlag(project, "solid", true) ? "yes" : "no";
        auto baseNameOut = extra(project, "outputBaseFilename", project.name ~ "-setup");
        auto script = `[Setup]
AppName=` ~ project.name ~ `
AppVersion=` ~ project.version_ ~ `
AppPublisher=` ~ project.publisher ~ `
DefaultDirName={autopf}\\` ~ project.name ~ `
OutputDir=.
OutputBaseFilename=` ~ baseNameOut ~ `
Compression=` ~ compression ~ `
SolidCompression=` ~ solid ~ `
` ~ pathFlag ~ `
[Files]
Source: "..\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
` ~ (project.addToPath ? `
[Registry]
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Flags: preservestringtype
` : "");
        write(iss, script);
        return "Wrote " ~ iss;
    }

    string build(const ref InstallerProject project, string outDir)
    {
        auto msg = emitSources(project, outDir);
        auto tool = detectTool();
        if (!tool.length)
            return msg ~ "\nISCC not found — run: ibex plugins install-tool inno";
        auto iss = buildPath(outDir, project.name ~ ".iss");
        auto r = executeShell(`"` ~ tool ~ `" "` ~ iss ~ `"`);
        if (r.status != 0)
            return msg ~ "\nISCC failed:\n" ~ r.output;
        return msg ~ "\n" ~ r.output;
    }
}

shared static this()
{
    registerBuiltin(new InnoPlugin());
}
