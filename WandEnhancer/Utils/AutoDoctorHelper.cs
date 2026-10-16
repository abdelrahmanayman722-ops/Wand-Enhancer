using System;
using System.IO;
using System.Linq;
using System.Threading;
using WandEnhancer.Core;
using WandEnhancer.Core.Patching.Shared;
using WandEnhancer.Core.Patching.Strategies.Static;
using WandEnhancer.Models;

namespace WandEnhancer.Utils
{
    /// <summary>
    /// Integrated automated diagnostic and self-healing system for SovereignTitan.
    /// Inspects and repairs Windows permissions, process locks, firewall rules, and ASAR health in one click.
    /// </summary>
    public static class AutoDoctorHelper
    {
        public static void RunAutoDoctor(WeModConfig config, Action<string, ELogType> log)
        {
            if (log == null) return;

            log("╔══════════════════════════════════════════════════════════════════╗", ELogType.Info);
            log("║   [AUTO-DOCTOR] SovereignTitan Environment Diagnostic & Healer   ║", ELogType.Info);
            log("╚══════════════════════════════════════════════════════════════════╝", ELogType.Info);

            int repairsMade = 0;
            int warnings = 0;

            // 1. Process Locks Inspection & Automatic Release
            log("[1/4] Checking Process Locks & Background Instances...", ELogType.Info);
            try
            {
                bool isRunning = ProcessTerminator.IsRunning(config?.BrandName ?? "WeMod");
                if (isRunning)
                {
                    log("[!] Detected running WeMod / Wand process locking files. Releasing locks...", ELogType.Warn);
                    ProcessTerminator.TryKillProcess(config?.BrandName ?? "WeMod");
                    Thread.Sleep(1000);
                    if (!ProcessTerminator.IsRunning(config?.BrandName ?? "WeMod"))
                    {
                        log("[+] Successfully terminated locked process tree.", ELogType.Success);
                        repairsMade++;
                    }
                    else
                    {
                        log("[-] Could not terminate all process instances. Manual exit may be needed.", ELogType.Warn);
                        warnings++;
                    }
                }
                else
                {
                    log("[+] No conflicting processes detected (workspace is free).", ELogType.Success);
                }
            }
            catch (Exception ex)
            {
                log($"[!] Process inspection warning: {ex.Message}", ELogType.Warn);
                warnings++;
            }

            // 2. Windows Permissions & File Attributes Self-Healing
            log("[2/4] Inspecting Directory & File Permissions...", ELogType.Info);
            if (config == null || string.IsNullOrEmpty(config.RootDirectory) || !Directory.Exists(config.RootDirectory))
            {
                log("[-] Target installation folder not detected. Please select the folder above.", ELogType.Error);
                warnings++;
            }
            else
            {
                try
                {
                    // Repair directory attributes
                    var dirInfo = new DirectoryInfo(config.RootDirectory);
                    if (dirInfo.Attributes.HasFlag(FileAttributes.ReadOnly))
                    {
                        dirInfo.Attributes &= ~FileAttributes.ReadOnly;
                        log($"[+] Removed ReadOnly flag from installation root: {config.RootDirectory}", ELogType.Success);
                        repairsMade++;
                    }

                    // Repair crucial file attributes
                    string[] targetFiles = new[]
                    {
                        config.ExecutablePath,
                        Path.Combine(config.RootDirectory, "resources", "app.asar"),
                        Path.Combine(config.RootDirectory, "resources", "app.asar.backup")
                    };

                    foreach (var file in targetFiles)
                    {
                        if (File.Exists(file))
                        {
                            var fi = new FileInfo(file);
                            if (fi.Attributes.HasFlag(FileAttributes.ReadOnly))
                            {
                                fi.Attributes &= ~FileAttributes.ReadOnly;
                                log($"[+] Cleared ReadOnly flag on '{fi.Name}'", ELogType.Success);
                                repairsMade++;
                            }
                        }
                    }

                    // Check write permission on app.asar
                    string asarPath = Path.Combine(config.RootDirectory, "resources", "app.asar");
                    if (File.Exists(asarPath))
                    {
                        bool writable = false;
                        try
                        {
                            using (var fs = new FileStream(asarPath, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite))
                            {
                                writable = true;
                            }
                        }
                        catch (Exception ex)
                        {
                            log($"[!] Warning: app.asar write test encountered: {ex.Message}", ELogType.Warn);
                            warnings++;
                        }

                        if (writable)
                        {
                            log("[+] Permissions verified: app.asar is fully writable.", ELogType.Success);
                        }
                    }
                }
                catch (Exception ex)
                {
                    log($"[!] Permission healing warning: {ex.Message}", ELogType.Warn);
                    warnings++;
                }
            }

            // 3. Windows Firewall Rule Healing
            log("[3/4] Checking Windows Firewall Inbound Rules (Port 3223)...", ELogType.Info);
            try
            {
                if (FirewallHelper.IsRulePresent())
                {
                    log("[+] Firewall rule for port 3223 is ACTIVE & HEALTHY.", ELogType.Success);
                }
                else
                {
                    log("[!] Inbound firewall rule for port 3223 is missing. Auto-configuring...", ELogType.Warn);
                    bool added = FirewallHelper.AddFirewallRule(FirewallHelper.DefaultPort, FirewallHelper.DefaultRuleName, log);
                    if (added)
                    {
                        log("[+] Successfully configured inbound firewall rule for port 3223.", ELogType.Success);
                        repairsMade++;
                    }
                    else
                    {
                        log("[-] Firewall auto-configuration was skipped or cancelled by user.", ELogType.Warn);
                        warnings++;
                    }
                }
            }
            catch (Exception ex)
            {
                log($"[!] Firewall rule check failed: {ex.Message}", ELogType.Warn);
                warnings++;
            }

            // 4. ASAR Health & Backup Integrity Check
            log("[4/4] Validating ASAR Archive Health & Header Hash...", ELogType.Info);
            if (config != null && !string.IsNullOrEmpty(config.RootDirectory))
            {
                string resourcesDir = Path.Combine(config.RootDirectory, "resources");
                string asarPath = Path.Combine(resourcesDir, "app.asar");
                string asarBackupPath = Path.Combine(resourcesDir, "app.asar.backup");
                string unpackedDir = Path.Combine(resourcesDir, "app.asar.unpacked");
                string unpackedBackup = Path.Combine(resourcesDir, "app.asar.unpacked.backup");

                if (File.Exists(asarPath))
                {
                    try
                    {
                        string headerHash = AsarHeaderHash.Compute(asarPath);
                        log($"[+] ASAR Archive Header verified healthy (SHA256: {headerHash.Substring(0, 16)}...).", ELogType.Success);

                        bool isAlreadyPatched = IsArchiveOrInstallPatched(config, asarPath, unpackedDir);

                        // Ensure backup exists
                        if (!File.Exists(asarBackupPath))
                        {
                            if (isAlreadyPatched)
                            {
                                log("[!] app.asar is currently patched but pristine backup is missing.", ELogType.Warn);
                                log("[-] Cannot create pristine backup from a modified archive. Reinstall or verify files.", ELogType.Warn);
                                warnings++;
                            }
                            else
                            {
                                log("[!] Pristine backup missing. Creating protective backup now...", ELogType.Info);
                                FileRetry.Run(() => File.Copy(asarPath, asarBackupPath, false));
                                log($"[+] Created pristine ASAR backup at '{asarBackupPath}'.", ELogType.Success);
                                repairsMade++;
                            }
                        }
                        else
                        {
                            log("[+] Pristine ASAR backup exists and is secure.", ELogType.Success);
                        }

                        // Check unpacked backup
                        if (Directory.Exists(unpackedDir) && !Directory.Exists(unpackedBackup))
                        {
                            if (isAlreadyPatched)
                            {
                                log("[!] app.asar.unpacked backup is missing while patched. Cannot create pristine backup from modified directory.", ELogType.Warn);
                                warnings++;
                            }
                            else
                            {
                                log("[!] Unpacked backup missing. Creating protective directory copy...", ELogType.Info);
                                FileRetry.Run(() => AsarSharp.Utils.Extensions.CopyDirectory(unpackedDir, unpackedBackup));
                                log("[+] Created pristine unpacked backup directory.", ELogType.Success);
                                repairsMade++;
                            }
                        }

                        // Synchronize PE integrity resource if present in executable
                        if (File.Exists(config.ExecutablePath))
                        {
                            try
                            {
                                bool patchedResource = AsarIntegrityResourcePatch.Patch(config.ExecutablePath, asarPath, log);
                                if (patchedResource)
                                {
                                    log("[+] ASAR PE integrity resource synchronized with app.asar header hash.", ELogType.Success);
                                }
                            }
                            catch (Exception ex)
                            {
                                log($"[!] Warning verifying PE integrity resource: {ex.Message}", ELogType.Warn);
                                warnings++;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        log($"[-] ASAR integrity check error: {ex.Message}", ELogType.Error);
                        warnings++;
                    }
                }
                else
                {
                    log($"[-] Critical: app.asar missing at '{asarPath}'", ELogType.Error);
                    warnings++;
                }
            }

            // Summary
            log("══════════════════════════════════════════════════════════════════", ELogType.Info);
            if (repairsMade > 0)
            {
                log($"[AUTO-DOCTOR] Self-healing complete: {repairsMade} repair(s) performed successfully!", ELogType.Success);
            }
            else if (warnings == 0)
            {
                log("[AUTO-DOCTOR] System is 100% HEALTHY! All environments and permissions are optimal.", ELogType.Success);
            }
            else
            {
                log($"[AUTO-DOCTOR] System check completed with {warnings} warning(s). Review logs above.", ELogType.Warn);
            }
        }

        private static bool IsArchiveOrInstallPatched(WeModConfig config, string asarPath, string unpackedDir)
        {
            if (config == null) return false;

            if (Enhancer.IsPatched(config.RootDirectory))
            {
                return true;
            }

            string resourcesDir = Path.Combine(config.RootDirectory, "resources");
            if (File.Exists(Path.Combine(resourcesDir, ".incomplete-patch")))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(config.ExecutablePath) && File.Exists(config.ExecutablePath + ".fusebak"))
            {
                return true;
            }

            if (Directory.Exists(unpackedDir) && Directory.Exists(Path.Combine(unpackedDir, "remote-panel")))
            {
                return true;
            }

            if (File.Exists(asarPath))
            {
                try
                {
                    var header = AsarSharp.AsarFileSystem.Disk.ReadArchiveHeaderSync(asarPath);
                    if (header != null && !string.IsNullOrEmpty(header.HeaderString))
                    {
                        if (header.HeaderString.Contains("\"remote-panel\"") ||
                            header.HeaderString.Contains("remote-bridge-boot") ||
                            header.HeaderString.Contains("pro-account-reducer"))
                        {
                            return true;
                        }
                    }
                }
                catch
                {
                    // If archive cannot be parsed or read, treat with caution
                }
            }

            return false;
        }
    }
}
