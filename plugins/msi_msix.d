module easyinstaller.plugins.msi_msix;

import easyinstaller.plugin;
import easyinstaller.project : InstallerProject, extra;
import std.file : exists, mkdirRecurse, write;
import std.path : buildPath, baseName, dirName;
import std.process : executeShell, environment;
import std.string : strip, splitLines;
import std.array : replace;

string findMsiGenerator()
{
    auto env = environment.get("MSI_GENERATOR", "");
    if (env.length && exists(env))
        return env;
    auto w = which("msi-generator");
    if (w.length)
        return w;
    version (Windows)
    {
        string[] candidates = [
            `C:\code\github.com\dev-centr\msi-generator\msi-generator.exe`,
            buildPath(dirName(thisExeDir()), "..", "msi-generator", "msi-generator.exe"),
        ];
        foreach (c; candidates)
            if (exists(c))
                return c;
    }
    return "";
}

private string thisExeDir()
{
    import std.file : thisExePath;
    import std.path : dirName;
    return dirName(thisExePath());
}

abstract class MsiGeneratorBackedPlugin : InstallerPlugin
{
    abstract string packageType(); // msi | msix

    string[] targets() { return ["windows"]; }
    bool canBuild() { return findMsiGenerator().length > 0; }
    string detectTool() { return findMsiGenerator(); }
    string guiName() { return "msi-generator (CLI engine)"; }
    string guiInstallUrl() { return "https://github.com/dev-centr/msi-generator/releases"; }
    string guiDetectHint() { return "Put msi-generator on PATH or set MSI_GENERATOR"; }
    string detectGui() { return ""; }
    string installPlaybook() { return "install-msi-generator.cmk"; }
    ExtraField[] extrasSchema()
    {
        return [
            ExtraField("productCode", "string", "00000000-0000-0000-0000-000000000001", "MSI ProductCode GUID"),
            ExtraField("upgradeCode", "string", "00000000-0000-0000-0000-000000000002", "MSI UpgradeCode GUID"),
        ];
    }
    string designerSource(const ref InstallerProject project, string outDir)
    {
        return buildPath(outDir, project.name ~ "-" ~ packageType() ~ "-spec.json");
    }

    string emitSources(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        // Write a minimal JSON spec for msi-generator --spec
        auto specPath = buildPath(outDir, project.name ~ "-" ~ packageType() ~ "-spec.json");
        auto exe = project.exe.length ? project.exe : "";
        auto productCode = extra(project, "productCode", "00000000-0000-0000-0000-000000000001");
        auto upgradeCode = extra(project, "upgradeCode", "00000000-0000-0000-0000-000000000002");
        auto json = `{
  "name": "` ~ project.name ~ `",
  "manufacturer": "` ~ project.publisher ~ `",
  "productVersion": "` ~ normalizeFourPart(project.version_) ~ `",
  "productCode": "` ~ productCode ~ `",
  "upgradeCode": "` ~ upgradeCode ~ `",
  "rootFolder": "INSTALLDIR",
  "components": [
    {
      "id": "MainComponent",
      "files": [
        { "sourcePath": "` ~ exe.replace(`\`, `/`) ~ `", "destName": "` ~ baseName(exe) ~ `" }
      ],
      "registryEntries": []
    }
  ],
  "features": [ { "id": "Complete", "title": "Complete", "components": ["MainComponent"] } ]
}
`;
        write(specPath, json);
        return "Wrote " ~ specPath;
    }

    string build(const ref InstallerProject project, string outDir)
    {
        auto msg = emitSources(project, outDir);
        auto tool = findMsiGenerator();
        if (!tool.length)
            return msg ~ "\nmsi-generator not found — " ~ guiDetectHint();
        auto ext = packageType() == "msi" ? ".msi" : ".msix";
        auto outFile = buildPath(outDir, project.name ~ "-" ~ project.version_ ~ ext);
        auto specPath = buildPath(outDir, project.name ~ "-" ~ packageType() ~ "-spec.json");
        string cmd;
        if (project.exe.length)
        {
            cmd = `"` ~ tool ~ `" --type=` ~ packageType()
                ~ ` --name="` ~ project.name ~ `"`
                ~ ` --id="` ~ project.id ~ `"`
                ~ ` --version="` ~ normalizeFourPart(project.version_) ~ `"`
                ~ ` --publisher="` ~ project.publisher ~ `"`
                ~ ` --exe="` ~ project.exe ~ `"`
                ~ ` --output="` ~ outFile ~ `"`;
            if (packageType() == "msi")
                cmd = `"` ~ tool ~ `" --type=msi --spec="` ~ specPath ~ `" --output="` ~ outFile ~ `"`;
        }
        else
            cmd = `"` ~ tool ~ `" --type=` ~ packageType()
                ~ ` --spec="` ~ specPath ~ `" --output="` ~ outFile ~ `"`;

        auto r = executeShell(cmd);
        if (r.status != 0)
            return msg ~ "\nmsi-generator failed:\n" ~ r.output
                ~ "\n(Note: MSI writer may still be maturing — see msi-generator releases.)";
        return msg ~ "\n" ~ r.output ~ "\nOutput: " ~ outFile;
    }

    private string normalizeFourPart(string v)
    {
        import std.array : split;
        auto parts = v.split(".");
        while (parts.length < 4)
            parts ~= "0";
        return parts[0] ~ "." ~ parts[1] ~ "." ~ parts[2] ~ "." ~ parts[3];
    }
}

final class MsiPlugin : MsiGeneratorBackedPlugin
{
    string id() { return "msi"; }
    string displayName() { return "MSI (msi-generator)"; }
    override string packageType() { return "msi"; }
}

final class MsixPlugin : MsiGeneratorBackedPlugin
{
    string id() { return "msix"; }
    string displayName() { return "MSIX (msi-generator)"; }
    override string packageType() { return "msix"; }
}

shared static this()
{
    registerBuiltin(new MsiPlugin());
    registerBuiltin(new MsixPlugin());
}
