module easyinstaller.versioninfo;

/// Stamped at CI via -version=BuildId_… or fallback.
enum string appName = "easy-installer";
enum string appVersion = "0.1.0";

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
    return format("%s %s (build %s)", appName, appVersion, buildId());
}
