using System;
using System.Reflection;

namespace WandEnhancer
{
    public static class Constants
    {
        public const string BrandName = "SovereignTitan";
        public const string BrandNameArabic = "سوفيرين تيتان";
        public const string Author = "Abdelrahman Ayman (@abdelrahmanayman722-ops)";
        public const string RepoName = "Wand-Enhancer";
        public const string Owner = "k1tbyte";
        public static readonly string RepositoryUrl = $"https://github.com/{Owner}/{RepoName}";
        public static readonly Version Version;

        public static readonly string Build;

        public static readonly string[] WeModBrandNames = { "Wand", "WeMod" };
        public const string AppSettingsFileName = "appsettings.json";
        public const string AutoPatchConfigFileName = "enhancer.json";

        static Constants()
        {
            Version = Assembly.GetExecutingAssembly().GetName().Version;
            Build = string.IsNullOrEmpty(BuildStamp.Value) ? "unofficial" : BuildStamp.Value;
        }
    }
}
