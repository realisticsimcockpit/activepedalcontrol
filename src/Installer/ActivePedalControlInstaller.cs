using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;

[assembly: AssemblyTitle("Active Pedal Control Setup")]
[assembly: AssemblyProduct("Active Pedal Control")]
[assembly: AssemblyCompany("Realistic Simcockpit")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

namespace ActivePedalControlInstaller
{
    internal static class Program
    {
        private const string DefaultSimHubPath = @"C:\Program Files (x86)\SimHub";
        private const string BasicDashboardName = "Active Pedal Control Basic V1.0";
        private const string Gt1DashboardName = "Active Pedal Control GT1 V1.0";

        [STAThread]
        private static int Main(string[] args)
        {
            string simHubPath = DefaultSimHubPath;
            bool installPlugin = true;

            for (int i = 0; i < args.Length; i++)
            {
                string arg = args[i] ?? string.Empty;
                if (arg.Equals("/no-plugin", StringComparison.OrdinalIgnoreCase))
                {
                    installPlugin = false;
                }
                else if (arg.StartsWith("/simhub=", StringComparison.OrdinalIgnoreCase))
                {
                    simHubPath = arg.Substring("/simhub=".Length).Trim('"');
                }
                else if (arg.Equals("/simhub", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    i++;
                    simHubPath = args[i].Trim('"');
                }
            }

            try
            {
                Console.WriteLine("Active Pedal Control installer");
                Console.WriteLine("SimHub path: " + simHubPath);

                if (!IsAdministrator())
                {
                    Console.Error.WriteLine("This installer must be run as administrator.");
                    return 10;
                }

                if (!Directory.Exists(simHubPath))
                {
                    Console.Error.WriteLine("SimHub folder was not found: " + simHubPath);
                    return 11;
                }

                string dashTemplatesPath = Path.Combine(simHubPath, "DashTemplates");
                if (!Directory.Exists(dashTemplatesPath))
                {
                    Console.Error.WriteLine("DashTemplates folder was not found: " + dashTemplatesPath);
                    return 12;
                }

                if (Process.GetProcessesByName("SimHubWPF").Length > 0)
                {
                    Console.Error.WriteLine("SimHub is running. Close SimHub before installing.");
                    return 13;
                }

                string tempPath = Path.Combine(Path.GetTempPath(), "ActivePedalControlInstaller_" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(tempPath);

                try
                {
                    string pluginPath = Path.Combine(tempPath, "ActivePedalBridge.dll");
                    string basicZipPath = Path.Combine(tempPath, "Basic.zip");
                    string gt1ZipPath = Path.Combine(tempPath, "GT1.zip");

                    WriteResource("ActivePedalBridge.dll", pluginPath);
                    WriteResource("BasicDashboard.zip", basicZipPath);
                    WriteResource("GT1Dashboard.zip", gt1ZipPath);

                    if (installPlugin)
                    {
                        string targetPluginPath = Path.Combine(simHubPath, "ActivePedalBridge.dll");
                        File.Copy(pluginPath, targetPluginPath, true);
                        Console.WriteLine("Installed plugin: " + targetPluginPath);
                    }

                    InstallDashboard(basicZipPath, dashTemplatesPath, BasicDashboardName);
                    InstallDashboard(gt1ZipPath, dashTemplatesPath, Gt1DashboardName);
                }
                finally
                {
                    TryDeleteDirectory(tempPath);
                }

                Console.WriteLine("Installation completed.");
                Console.WriteLine("Restart SimHub and open either Active Pedal Control dashboard style.");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Installation failed: " + ex.Message);
                return 1;
            }
        }

        private static bool IsAdministrator()
        {
            WindowsIdentity identity = WindowsIdentity.GetCurrent();
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }

        private static void InstallDashboard(string zipPath, string dashTemplatesPath, string dashboardName)
        {
            string targetPath = Path.Combine(dashTemplatesPath, dashboardName);
            EnsureChildPath(dashTemplatesPath, targetPath);

            if (Directory.Exists(targetPath))
            {
                Directory.Delete(targetPath, true);
            }

            Directory.CreateDirectory(targetPath);
            ExpandZipWithPowerShell(zipPath, targetPath);
            Console.WriteLine("Installed dashboard: " + targetPath);
        }

        private static void ExpandZipWithPowerShell(string zipPath, string targetPath)
        {
            string scriptPath = Path.Combine(Path.GetTempPath(), "ActivePedalControlExpand_" + Guid.NewGuid().ToString("N") + ".ps1");
            string script =
                "$ErrorActionPreference = 'Stop'\r\n" +
                "Expand-Archive -LiteralPath '" + EscapePowerShell(zipPath) + "' -DestinationPath '" + EscapePowerShell(targetPath) + "' -Force\r\n";

            File.WriteAllText(scriptPath, script);
            try
            {
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = "powershell.exe";
                startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"";
                startInfo.UseShellExecute = false;
                startInfo.RedirectStandardOutput = true;
                startInfo.RedirectStandardError = true;

                using (Process process = Process.Start(startInfo))
                {
                    string output = process.StandardOutput.ReadToEnd();
                    string error = process.StandardError.ReadToEnd();
                    process.WaitForExit();

                    if (process.ExitCode != 0)
                    {
                        throw new InvalidOperationException("Dashboard extraction failed. " + error + output);
                    }
                }
            }
            finally
            {
                try
                {
                    File.Delete(scriptPath);
                }
                catch
                {
                }
            }
        }

        private static void WriteResource(string resourceName, string outputPath)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream input = assembly.GetManifestResourceStream(resourceName))
            {
                if (input == null)
                {
                    throw new InvalidOperationException("Embedded resource not found: " + resourceName);
                }

                using (FileStream output = File.Create(outputPath))
                {
                    input.CopyTo(output);
                }
            }
        }

        private static void EnsureChildPath(string parentPath, string childPath)
        {
            string parent = Path.GetFullPath(parentPath).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            string child = Path.GetFullPath(childPath);
            if (!child.StartsWith(parent, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Refusing to write outside DashTemplates: " + child);
            }
        }

        private static string EscapePowerShell(string value)
        {
            return value.Replace("'", "''");
        }

        private static void TryDeleteDirectory(string path)
        {
            try
            {
                if (Directory.Exists(path))
                {
                    Directory.Delete(path, true);
                }
            }
            catch
            {
            }
        }
    }
}
