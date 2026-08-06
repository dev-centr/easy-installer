module easyinstaller.shell_hooks;

import std.file : thisExePath, exists, mkdirRecurse, write, copy, remove;
import std.path : buildPath, dirName;
import std.process : executeShell;
import std.string : replace, strip;
import std.conv : to;

string installShell()
{
    version (Windows)
        return installWindowsShell();
    else version (OSX)
        return installMacShell();
    else
        return installLinuxShell();
}

string uninstallShell()
{
    version (Windows)
        return uninstallWindowsShell();
    else version (OSX)
        return "Remove Easy Installer Quick Actions from ~/Library/Services if you added them.";
    else
        return uninstallLinuxShell();
}

version (Windows)
{
    private string regQuote(string s)
    {
        return s.replace(`"`, `\"`);
    }

    private string cascadeRoot(string classKey)
    {
        return `HKCU\Software\Classes\` ~ classKey ~ `\shell\EasyInstaller`;
    }

    private string installClassicWindows()
    {
        auto exe = thisExePath();
        string[] errors;
        foreach (ck; [`Directory`, `Directory\Background`])
        {
            auto root = cascadeRoot(ck);
            void run(string cmd)
            {
                auto r = executeShell(cmd);
                if (r.status != 0)
                    errors ~= r.output;
            }
            run(`reg add "` ~ root ~ `" /v MUIVerb /d "Easy Installer" /f`);
            run(`reg add "` ~ root ~ `" /v SubCommands /d "" /f`);
            run(`reg add "` ~ root ~ `" /v Icon /d "` ~ regQuote(exe) ~ `" /f`);

            auto ip = root ~ `\shell\01inplace`;
            run(`reg add "` ~ ip ~ `" /ve /d "Install in-place (add to PATH)" /f`);
            run(`reg add "` ~ ip ~ `\command" /ve /d "\"` ~ regQuote(exe)
                ~ `\" inplace-path add \"%V\"" /f`);

            auto np = root ~ `\shell\02newproj`;
            run(`reg add "` ~ np ~ `" /ve /d "New Installer Project" /f`);
            run(`reg add "` ~ np ~ `\command" /ve /d "\"` ~ regQuote(exe)
                ~ `\" new-project \"%V\"" /f`);
        }

        executeShell(`reg add "HKCU\Software\Classes\.easyinstaller" /ve /d "EasyInstaller.Project" /f`);
        executeShell(`reg add "HKCU\Software\Classes\EasyInstaller.Project" /ve /d "Installer Project" /f`);
        auto shellNew = `HKCU\Software\Classes\.easyinstaller\ShellNew`;
        executeShell(`reg add "` ~ shellNew ~ `" /v NullFile /d "" /f`);
        executeShell(`reg add "HKCU\Software\Classes\EasyInstaller.Project\shell\open\command" /ve /d "\"`
            ~ regQuote(exe) ~ `\" new-project \"%1\"" /f`);

        if (errors.length)
            return "Classic menu installed with warnings.";
        return "Classic Explorer menu + New-menu type fallback installed (current user).";
    }

    private bool isWin11OrNewer()
    {
        auto r = executeShell(
            `powershell -NoProfile -Command "[int](Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').CurrentBuildNumber"`);
        if (r.status != 0)
            return false;
        try
            return to!int(r.output.strip) >= 22000;
        catch (Exception)
            return false;
    }

    private string tryModernSparse()
    {
        auto exeDir = dirName(thisExePath());
        string man = buildPath(exeDir, "shell", "sparse-package", "AppxManifest.xml");
        string dll = buildPath(exeDir, "shell", "explorer_command", "build", "EasyInstallerExplorerCommand.dll");
        if (!exists(man))
            man = buildPath(exeDir, "..", "shell", "sparse-package", "AppxManifest.xml");
        if (!exists(dll))
            dll = buildPath(exeDir, "..", "shell", "explorer_command", "build", "EasyInstallerExplorerCommand.dll");
        if (!exists(man) || !exists(dll))
            return "";
        auto staging = buildPath(exeDir, "shell-staging");
        mkdirRecurse(staging);
        mkdirRecurse(buildPath(staging, "Assets"));
        copy(dll, buildPath(staging, "EasyInstallerExplorerCommand.dll"));
        copy(man, buildPath(staging, "AppxManifest.xml"));
        copy(thisExePath(), buildPath(staging, "easy-installer.exe"));
        auto logoSrc = buildPath(dirName(man), "Assets", "StoreLogo.png");
        if (exists(logoSrc))
            copy(logoSrc, buildPath(staging, "Assets", "StoreLogo.png"));
        auto r = executeShell(`powershell -NoProfile -Command "Add-AppxPackage -Register '`
            ~ buildPath(staging, "AppxManifest.xml") ~ `'"`);
        if (r.status != 0)
            return "";
        return "Modern Win11 Explorer menu registered (sparse package).";
    }

    private string installWindowsShell()
    {
        if (isWin11OrNewer())
        {
            auto modern = tryModernSparse();
            if (modern.length)
                return modern;
            return "Modern sparse package unavailable (build shell DLL / Developer Mode). "
                ~ "Falling back to classic.\n" ~ installClassicWindows();
        }
        return installClassicWindows();
    }

    private string uninstallWindowsShell()
    {
        executeShell(`powershell -NoProfile -Command "Get-AppxPackage -Name 'DevCentr.EasyInstaller.Shell' | Remove-AppxPackage" 2>$null`);
        foreach (ck; [`Directory`, `Directory\Background`])
            executeShell(`reg delete "` ~ cascadeRoot(ck) ~ `" /f`);
        executeShell(`reg delete "HKCU\Software\Classes\.easyinstaller" /f`);
        executeShell(`reg delete "HKCU\Software\Classes\EasyInstaller.Project" /f`);
        return "Shell integration removed (best effort).";
    }
}
else version (OSX)
{
    private string installMacShell()
    {
        import std.path : expandTilde;
        auto services = expandTilde("~/Library/Services");
        mkdirRecurse(services);
        auto readme = buildPath(services, "EasyInstaller-README.txt");
        write(readme, "Create a Quick Action in Automator:\n"
            ~ "1. Workflow receives folders in Finder\n"
            ~ "2. Run Shell Script: \"" ~ thisExePath() ~ "\" inplace-path add \"$@\"\n"
            ~ "Save as 'Install in-place (add to PATH)'.\n");
        return "Wrote Finder Quick Action instructions to " ~ readme;
    }
}
else
{
    private string installLinuxShell()
    {
        import std.path : expandTilde;
        auto exe = thisExePath();
        auto actions = expandTilde("~/.local/share/file-manager/actions");
        mkdirRecurse(actions);
        void writeDesktop(string name, string label, string modeArgs)
        {
            write(buildPath(actions, name),
                "[Desktop Entry]\nType=Action\nName=" ~ label ~ "\n"
                ~ "Profiles=on_folder;\n\n[X-Action-Profile on_folder]\n"
                ~ "MimeTypes=inode/directory;\n"
                ~ "Exec=" ~ exe ~ " " ~ modeArgs ~ " %f\n");
        }
        writeDesktop("easy-installer-inplace.desktop",
            "Install in-place (add to PATH)", "inplace-path add");
        writeDesktop("easy-installer-new.desktop",
            "New Installer Project", "new-project");

        auto nemo = expandTilde("~/.local/share/nemo/actions");
        mkdirRecurse(nemo);
        write(buildPath(nemo, "easy-installer-inplace.nemo_action"),
            "[Nemo Action]\nName=Install in-place (add to PATH)\n"
            ~ "Exec=" ~ exe ~ " inplace-path add %F\nSelection=s\nExtensions=dir;\n");

        return "Linux file-manager actions installed under ~/.local/share/file-manager/actions.";
    }

    private string uninstallLinuxShell()
    {
        import std.path : expandTilde;
        string[] files = [
            expandTilde("~/.local/share/file-manager/actions/easy-installer-inplace.desktop"),
            expandTilde("~/.local/share/file-manager/actions/easy-installer-new.desktop"),
            expandTilde("~/.local/share/nemo/actions/easy-installer-inplace.nemo_action"),
        ];
        foreach (f; files)
            if (exists(f))
                remove(f);
        return "Linux file-manager actions removed.";
    }
}
