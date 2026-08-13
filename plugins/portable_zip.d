module easyinstaller.plugins.portable_zip;

import easyinstaller.plugin;
import easyinstaller.project : InstallerProject;
import std.file : exists, mkdirRecurse, dirEntries, SpanMode, read, write, isDir, isFile;
import std.path : buildPath, baseName, relativePath, absolutePath;
import std.zip;
import std.algorithm : canFind, endsWith;
import std.string : startsWith;

final class PortableZipPlugin : InstallerPlugin
{
    string id() { return "portable-zip"; }
    string displayName() { return "Portable ZIP"; }
    string[] targets() { return ["all"]; }
    bool canBuild() { return true; }
    string detectTool() { return "(built-in)"; }
    string guiName() { return ""; }
    string guiInstallUrl() { return ""; }
    string guiDetectHint() { return ""; }
    string detectGui() { return ""; }
    string installPlaybook() { return ""; }
    ExtraField[] extrasSchema() { return noExtras(); }
    string designerSource(const ref InstallerProject project, string outDir)
    {
        return "";
    }

    string emitSources(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        return "portable-zip has no intermediate sources; use build.";
    }

    string build(const ref InstallerProject project, string outDir)
    {
        if (!exists(outDir))
            mkdirRecurse(outDir);
        auto outFile = buildPath(outDir, project.name ~ "-" ~ project.version_ ~ ".zip");
        auto zip = new ZipArchive();
        auto root = project.rootDir;

        void addFile(string absPath)
        {
            if (!exists(absPath) || !isFile(absPath))
                return;
            auto rel = relativePath(absPath, root);
            if (rel.startsWith("dist") || rel == "installer.kdl" || rel.endsWith(".zip"))
                return;
            auto member = new ArchiveMember();
            member.name = rel;
            member.expandedData = cast(ubyte[])read(absPath);
            member.compressionMethod = CompressionMethod.deflate;
            zip.addMember(member);
        }

        void walk(string dir)
        {
            foreach (e; dirEntries(dir, SpanMode.shallow))
            {
                auto name = baseName(e.name);
                if (name == "." || name == ".." || name == "dist" || name == ".git")
                    continue;
                if (e.isDir)
                    walk(e.name);
                else
                    addFile(e.name);
            }
        }

        bool globAll = project.files.canFind("*");
        if (globAll)
            walk(root);
        else
        {
            foreach (f; project.files)
            {
                auto abs = buildPath(root, f);
                if (exists(abs) && isDir(abs))
                    walk(abs);
                else
                    addFile(abs);
            }
        }

        write(outFile, zip.build());
        return "Wrote " ~ outFile;
    }
}

shared static this()
{
    registerBuiltin(new PortableZipPlugin());
}
