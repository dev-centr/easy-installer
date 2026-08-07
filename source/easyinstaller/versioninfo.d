module easyinstaller.versioninfo;

/// Stamped at CI via -version=BuildId_… or fallback.
enum string appName = "ibex";
enum string appDisplayName = "Ibex";
enum string appExpansion = "Install Builder EXtension";
enum string appVersion = "0.2.0";
enum string appTagline = "Install Builder Extension — author packages and put tools on PATH";

string buildId()
{
    version (BuildId_CI)
        return "ci";
    else
        return "local";
}

string aboutLine()
{
    import std.string : format;
    return format("%s %s (%s; build %s)", appName, appVersion, appExpansion, buildId());
}
