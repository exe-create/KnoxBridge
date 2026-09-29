using System.IO.Compression;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace KnoxBridge.Setup;

internal static class Program
{
    private const string Owner = "KnoxBridge Runtime";
    private const string AgentFile = "knoxbridge-agent.jar";
    private const string BootstrapFile = "knoxbridge-bootstrap.dll";
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true, PropertyNameCaseInsensitive = true };

    private static int Main(string[] args)
    {
        try
        {
            if (args.Length == 1 && args[0] == "--self-test") return SelfTest.Run();
            if (args.Length == 1 && args[0] == "--verify-payload")
            {
                var archive = InstallerPayload.ReadEmbeddedArchive();
                InstallerPayload.Parse(archive);
                Console.WriteLine($"KnoxBridge embedded payload verification PASS sha256={Convert.ToHexString(SHA256.HashData(archive))}");
                return 0;
            }
            Console.Title = "KnoxBridge Setup";
            var payload = InstallerPayload.ReadEmbedded();
            while (true)
            {
                Console.Clear();
                Console.WriteLine("KnoxBridge Setup");
                Console.WriteLine("This setup modifies only KnoxBridge-owned files and Project Zomboid startup configuration.");
                Console.WriteLine("Close Project Zomboid before installing or uninstalling.");
                Console.WriteLine("Java modules have the same permissions as Project Zomboid; approve only code you trust.");
                Console.WriteLine();
                Console.WriteLine("1. Install or update KnoxBridge Runtime");
                Console.WriteLine("2. Uninstall KnoxBridge");
                Console.WriteLine("3. Exit");
                Console.Write("Choose 1-3: ");
                switch (Console.ReadLine()?.Trim())
                {
                    case "1": RunAction(() =>
                    {
                        var game = FindGameFolder();
                        if (Confirm($"Install KnoxBridge into:\n{game}\n\nIt will back up ProjectZomboid64.json and add two KnoxBridge-owned startup arguments."))
                            InstallerCore.Install(game, payload);
                        else Console.WriteLine("Install cancelled; no files were changed.");
                    }); break;
                    case "2": RunAction(() =>
                    {
                        var game = FindGameFolder();
                        if (Confirm($"Uninstall KnoxBridge from:\n{game}\n\nOnly KnoxBridge-owned startup arguments and files will be removed."))
                            InstallerCore.Uninstall(game);
                        else Console.WriteLine("Uninstall cancelled; no files were changed.");
                    }); break;
                    case "3": return 0;
                    default: Console.WriteLine("Choose 1, 2, or 3."); Pause(); break;
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"KnoxBridge Setup could not continue safely: {ex.Message}");
            Pause();
            return 1;
        }
    }

    private static void RunAction(Action action)
    {
        try { action(); }
        catch (Exception ex) { Console.WriteLine($"\nSetup stopped safely: {ex.Message}"); }
        Pause();
    }

    private static void Pause()
    {
        Console.WriteLine();
        Console.Write("Press Enter to return to the menu.");
        Console.ReadLine();
    }

    private static bool Confirm(string message)
    {
        Console.WriteLine(message);
        Console.Write("Continue? [y/N]: ");
        return string.Equals(Console.ReadLine()?.Trim(), "Y", StringComparison.OrdinalIgnoreCase);
    }

    private static string FindGameFolder()
    {
        var candidates = new[]
        {
            @"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid",
            @"C:\Program Files\Steam\steamapps\common\ProjectZomboid",
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Steam\steamapps\common\ProjectZomboid")
        }.Distinct(StringComparer.OrdinalIgnoreCase);
        foreach (var candidate in candidates)
            if (File.Exists(Path.Combine(candidate, "ProjectZomboid64.json"))) return Path.GetFullPath(candidate);

        while (true)
        {
            Console.WriteLine("Project Zomboid was not found in the usual Steam folders.");
            Console.WriteLine("Enter the game folder containing ProjectZomboid64.json, or leave blank to cancel:");
            Console.Write("> ");
            var input = Console.ReadLine()?.Trim().Trim('"');
            if (string.IsNullOrEmpty(input)) throw new OperationCanceledException("No game folder was selected.");
            var full = Path.GetFullPath(input);
            if (File.Exists(Path.Combine(full, "ProjectZomboid64.json"))) return full;
            Console.WriteLine("That folder does not contain ProjectZomboid64.json.");
        }
    }

    private static void EnsureGameClosed()
    {
        var running = new[] { "ProjectZomboid64", "ProjectZomboid32", "ProjectZomboid" }
            .Where(name => Process.GetProcessesByName(name).Length > 0).ToArray();
        if (running.Length > 0) throw new InvalidOperationException("Close Project Zomboid before changing KnoxBridge setup. No changes were made.");
    }

    private static void AtomicWrite(string path, byte[] bytes)
    {
        var temp = path + ".knoxbridge.tmp";
        File.WriteAllBytes(temp, bytes);
        File.Move(temp, path, true);
    }

    private sealed record InstallState(string Owner, string Version, string AgentArgument, string AgentSha256,
        string BootstrapArgument, string BootstrapSha256, string InstalledJsonSha256, bool UserEditsPreserved,
        DateTimeOffset InstalledAt);

    private sealed record InstallerPayload(byte[] Agent, byte[] Bootstrap, string Version)
    {
        public static InstallerPayload ReadEmbedded()
        {
            return Parse(ReadEmbeddedArchive());
        }

        public static byte[] ReadEmbeddedArchive()
        {
            using var stream = typeof(Program).Assembly.GetManifestResourceStream("KnoxBridge.SetupPayload.zip")
                ?? throw new InvalidDataException("The bundled KnoxBridge package is missing.");
            using var output = new MemoryStream(); stream.CopyTo(output); return output.ToArray();
        }

        public static InstallerPayload Parse(byte[] archiveBytes)
        {
            using var stream = new MemoryStream(archiveBytes, writable: false);
            using var archive = new ZipArchive(stream, ZipArchiveMode.Read);
            var agentEntry = archive.Entries.SingleOrDefault(e => Regex.IsMatch(Path.GetFileName(e.FullName), @"^knoxbridge-agent-.+\.jar$"))
                ?? throw new InvalidDataException("The package has no KnoxBridge runtime JAR.");
            var bootstrapEntry = archive.GetEntry("bootstrap-windows/knoxbridge-bootstrap.dll")
                ?? throw new InvalidDataException("The package has no Windows startup helper.");
            var agent = ReadEntry(agentEntry);
            var bootstrap = ReadEntry(bootstrapEntry);
            VerifyChecksum(archive, agentEntry, agent);
            VerifyChecksum(archive, bootstrapEntry, bootstrap);
            var version = Regex.Match(agentEntry.Name, @"^knoxbridge-agent-(.+)\.jar$").Groups[1].Value;
            return new InstallerPayload(agent, bootstrap, version);
        }

        private static byte[] ReadEntry(ZipArchiveEntry entry)
        {
            using var input = entry.Open(); using var output = new MemoryStream(); input.CopyTo(output); return output.ToArray();
        }

        private static void VerifyChecksum(ZipArchive archive, ZipArchiveEntry entry, byte[] bytes)
        {
            var sidecar = archive.GetEntry(entry.FullName + ".sha256") ?? throw new InvalidDataException($"Checksum is missing for {entry.Name}.");
            using var reader = new StreamReader(sidecar.Open());
            var expected = reader.ReadLine()?.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault()?.ToLowerInvariant();
            var actual = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
            if (expected != actual) throw new InvalidDataException($"Checksum verification failed for {entry.Name}.");
        }
    }

    private static class InstallerCore
    {
        private static string StateDir(string game) => Path.Combine(game, ".knoxbridge");
        private static string StatePath(string game) => Path.Combine(StateDir(game), "install-state.json");
        private static string BackupPath(string game) => Path.Combine(StateDir(game), "ProjectZomboid64.json.original");
        private static string JsonPath(string game) => Path.Combine(game, "ProjectZomboid64.json");
        private static string AgentPath(string game) => Path.Combine(StateDir(game), AgentFile);
        private static string BootstrapPath(string game) => Path.Combine(StateDir(game), BootstrapFile);

        public static void Install(string game, InstallerPayload payload)
        {
            EnsureGameClosed();
            game = Path.GetFullPath(game);
            var jsonPath = JsonPath(game);
            if (!File.Exists(jsonPath)) throw new FileNotFoundException("ProjectZomboid64.json was not found in the selected game folder.");
            RejectAlternateLauncherConflict(game);
            var originalJson = File.ReadAllBytes(jsonPath);
            var originalHash = Hash(originalJson);
            var root = JsonNode.Parse(originalJson) as JsonObject ?? throw new InvalidDataException("ProjectZomboid64.json is not a JSON object.");
            if (root["vmArgs"] is not JsonArray vmArgs) throw new InvalidDataException("ProjectZomboid64.json has no vmArgs array; refusing to guess its structure.");

            var statePath = StatePath(game); var backupPath = BackupPath(game);
            var agentPath = AgentPath(game); var bootstrapPath = BootstrapPath(game);
            var hadState = File.Exists(statePath);
            InstallState? prior = hadState ? JsonSerializer.Deserialize<InstallState>(File.ReadAllText(statePath), JsonOptions) : null;
            if (hadState && (prior is null || prior.Owner != Owner)) throw new InvalidDataException("KnoxBridge install state is invalid or not owned by this installer.");
            if (prior != null) ValidateOwnedState(game, prior);
            if (!hadState && (File.Exists(backupPath) || File.Exists(agentPath) || File.Exists(bootstrapPath)))
                throw new IOException("Unmanaged KnoxBridge backup or runtime files already exist; refusing to overwrite them.");
            if (hadState && !File.Exists(backupPath)) throw new IOException("KnoxBridge backup is missing; refusing to repair or overwrite the install.");

            var agentArg = prior?.AgentArgument ?? "-javaagent:" + agentPath;
            var bootstrapArg = prior?.BootstrapArgument ?? "-agentpath:" + bootstrapPath;
            var allArgs = EnumerateVmArgs(root).ToList();
            var otherBootstrap = allArgs.Where(arg => arg != agentArg && arg != bootstrapArg).FirstOrDefault(IsRuntimeArgument);
            if (otherBootstrap != null) throw new InvalidOperationException("Another Java instrumentation runtime is configured. Remove it before installing KnoxBridge; only one runtime can own startup.");
            if (!hadState && vmArgs.Select(StringValue).Any(IsRuntimeArgument))
                throw new InvalidOperationException("A Java runtime is already configured in the main launcher options. Remove it before installing KnoxBridge.");
            if (!hadState && (vmArgs.Select(StringValue).Contains(agentArg) || vmArgs.Select(StringValue).Contains(bootstrapArg)))
                throw new InvalidOperationException("An unmanaged KnoxBridge startup entry already exists; refusing to claim it.");

            var userEdits = prior?.UserEditsPreserved == true || (prior != null && originalHash != prior.InstalledJsonSha256);
            var nextArgs = vmArgs.Select(StringValue).Where(arg => arg != agentArg && arg != bootstrapArg).ToList();
            nextArgs.Add(bootstrapArg); nextArgs.Add(agentArg);
            root["vmArgs"] = new JsonArray(nextArgs.Select(arg => (JsonNode?)JsonValue.Create(arg)).ToArray());
            var nextJson = JsonSerializer.SerializeToUtf8Bytes(root, JsonOptions).Concat(new byte[] { (byte)'\n' }).ToArray();
            var nextState = new InstallState(Owner, payload.Version, agentArg, Hash(payload.Agent), bootstrapArg, Hash(payload.Bootstrap), Hash(nextJson), userEdits, DateTimeOffset.UtcNow);
            var stateBytes = JsonSerializer.SerializeToUtf8Bytes(nextState, JsonOptions).Concat(new byte[] { (byte)'\n' }).ToArray();

            var oldAgent = File.Exists(agentPath) ? File.ReadAllBytes(agentPath) : null;
            var oldBootstrap = File.Exists(bootstrapPath) ? File.ReadAllBytes(bootstrapPath) : null;
            var createdBackup = false;
            try
            {
                Directory.CreateDirectory(StateDir(game));
                if (!hadState) { File.WriteAllBytes(backupPath, originalJson); createdBackup = true; }
                AtomicWrite(agentPath, payload.Agent);
                AtomicWrite(bootstrapPath, payload.Bootstrap);
                AtomicWrite(jsonPath, nextJson);
                AtomicWrite(statePath, stateBytes);
                Console.WriteLine($"KnoxBridge installed. Agent SHA-256: {nextState.AgentSha256}");
                Console.WriteLine("Enable KnoxBridge Runtime and Knox Survivors in the PZ Mods menu, then start through Steam. Review Java modules in the Bridge main-menu screen; unknown hashes remain blocked by default.");
            }
            catch
            {
                AtomicWrite(jsonPath, originalJson);
                RestoreFile(agentPath, oldAgent); RestoreFile(bootstrapPath, oldBootstrap);
                if (createdBackup) File.Delete(backupPath);
                if (File.Exists(statePath) && !hadState) File.Delete(statePath);
                throw;
            }
        }

        public static void Uninstall(string game)
        {
            EnsureGameClosed();
            game = Path.GetFullPath(game);
            var statePath = StatePath(game); var backupPath = BackupPath(game); var jsonPath = JsonPath(game);
            if (!File.Exists(statePath) || !File.Exists(backupPath)) throw new IOException("KnoxBridge install state or original configuration backup is missing; refusing uninstall.");
            var state = JsonSerializer.Deserialize<InstallState>(File.ReadAllText(statePath), JsonOptions);
            if (state is null || state.Owner != Owner) throw new InvalidDataException("KnoxBridge install state is invalid or not owned by this installer.");
            ValidateOwnedState(game, state);
            var current = File.ReadAllBytes(jsonPath);
            if (Hash(current) == state.InstalledJsonSha256 && !state.UserEditsPreserved)
            {
                AtomicWrite(jsonPath, File.ReadAllBytes(backupPath));
                Console.WriteLine("Restored the exact original ProjectZomboid64.json bytes.");
            }
            else
            {
                var root = JsonNode.Parse(current) as JsonObject ?? throw new InvalidDataException("Current launcher JSON is invalid; nothing was removed.");
                if (root["vmArgs"] is not JsonArray args) throw new InvalidDataException("Current launcher JSON has no vmArgs array; nothing was removed.");
                var kept = args.Select(StringValue).Where(arg => arg != state.AgentArgument && arg != state.BootstrapArgument).ToList();
                root["vmArgs"] = new JsonArray(kept.Select(arg => (JsonNode?)JsonValue.Create(arg)).ToArray());
                AtomicWrite(jsonPath, JsonSerializer.SerializeToUtf8Bytes(root, JsonOptions).Concat(new byte[] { (byte)'\n' }).ToArray());
                Console.WriteLine("Removed only KnoxBridge startup arguments; other launcher edits were preserved.");
            }
            File.Delete(AgentPath(game)); File.Delete(BootstrapPath(game)); File.Delete(statePath); File.Delete(backupPath);
            var dir = StateDir(game);
            if (Directory.Exists(dir) && !Directory.EnumerateFileSystemEntries(dir).Any()) Directory.Delete(dir);
            Console.WriteLine("KnoxBridge files and owned installation state were removed.");
        }

        private static void RejectAlternateLauncherConflict(string game)
        {
            var batch = Path.Combine(game, "ProjectZomboid64.bat");
            if (File.Exists(batch) && IsRuntimeArgument(File.ReadAllText(batch)))
                throw new InvalidOperationException("A Java runtime entry was found in ProjectZomboid64.bat. Remove that runtime before installing KnoxBridge.");
        }

        private static void ValidateOwnedState(string game, InstallState state)
        {
            if (!string.Equals(state.AgentArgument, "-javaagent:" + AgentPath(game), StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(state.BootstrapArgument, "-agentpath:" + BootstrapPath(game), StringComparison.OrdinalIgnoreCase) ||
                !Regex.IsMatch(state.AgentSha256, "^[0-9a-fA-F]{64}$") ||
                !Regex.IsMatch(state.BootstrapSha256, "^[0-9a-fA-F]{64}$") ||
                !Regex.IsMatch(state.InstalledJsonSha256, "^[0-9a-fA-F]{64}$"))
                throw new InvalidDataException("KnoxBridge state does not match this game's owned files; refusing to alter startup configuration.");
        }

        private static IEnumerable<string> EnumerateVmArgs(JsonObject root)
        {
            if (root["vmArgs"] is JsonArray main) foreach (var node in main) yield return StringValue(node);
            if (root["windows"] is JsonObject platforms)
                foreach (var pair in platforms)
                    if (pair.Value?["vmArgs"] is JsonArray args)
                        foreach (var node in args) yield return StringValue(node);
        }

        private static string StringValue(JsonNode? node) => node?.GetValue<string>() ?? string.Empty;
        private static bool IsRuntimeArgument(string arg) => Regex.IsMatch(arg, "(?i)(javaagent:|agentpath:|agentlib:)", RegexOptions.CultureInvariant);
        private static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
        private static void RestoreFile(string path, byte[]? old) { if (old == null) File.Delete(path); else AtomicWrite(path, old); }

    }

    private static class SelfTest
    {
        public static int Run()
        {
            var temp = Path.Combine(Path.GetTempPath(), "KnoxBridge-NativeInstaller-Test-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temp);
            try
            {
                var original = Encoding.UTF8.GetBytes("{\"mainClass\":\"zombie/gameStates/MainScreenState\",\"classpath\":[\".\",\"projectzomboid.jar\"],\"vmArgs\":[\"-Xmx4g\",\"-Duser=preserve\"]}");
                var agent = new byte[] { 1, 2, 3, 4 }; var bootstrap = new byte[] { 5, 6, 7, 8 };
                var payload = new InstallerPayload(agent, bootstrap, "self-test");
                var checkedArchive = MakePackageArchive(agent, bootstrap, corruptChecksum: false);
                var checkedPayload = InstallerPayload.Parse(checkedArchive);
                Check(checkedPayload.Agent.SequenceEqual(agent) && checkedPayload.Bootstrap.SequenceEqual(bootstrap), "installer accepts checksum-verified Java agent and bootstrap payload");
                var corruptArchive = MakePackageArchive(agent, bootstrap, corruptChecksum: true);
                var checksumBlocked = false;
                try { InstallerPayload.Parse(corruptArchive); } catch (InvalidDataException) { checksumBlocked = true; }
                Check(checksumBlocked, "installer rejects a mismatched bundled runtime checksum");
                var game = Path.Combine(temp, "game"); Directory.CreateDirectory(game);
                File.WriteAllBytes(Path.Combine(game, "ProjectZomboid64.json"), original);

                InstallerCore.Install(game, payload);
                var installedHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(game, "ProjectZomboid64.json"))));
                InstallerCore.Install(game, payload);
                Check(installedHash == Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(game, "ProjectZomboid64.json")))), "idempotent reinstall");
                Check(File.ReadAllBytes(Path.Combine(game, ".knoxbridge", AgentFile)).SequenceEqual(agent), "real agent bytes installed");
                InstallerCore.Uninstall(game);
                Check(File.ReadAllBytes(Path.Combine(game, "ProjectZomboid64.json")).SequenceEqual(original), "exact original JSON restored");

                InstallerCore.Install(game, payload);
                var editedRoot = JsonNode.Parse(File.ReadAllBytes(Path.Combine(game, "ProjectZomboid64.json")))!.AsObject();
                (editedRoot["vmArgs"]!.AsArray()).Add("-Duser=edit");
                File.WriteAllText(Path.Combine(game, "ProjectZomboid64.json"), editedRoot.ToJsonString(JsonOptions));
                InstallerCore.Uninstall(game);
                var afterEdit = JsonNode.Parse(File.ReadAllBytes(Path.Combine(game, "ProjectZomboid64.json")))!.AsObject();
                var remainingArgs = afterEdit["vmArgs"]!.AsArray().Select(node => node?.GetValue<string>() ?? string.Empty).ToArray();
                Check(remainingArgs.Contains("-Duser=edit") && !remainingArgs.Any(arg => Regex.IsMatch(arg, "(?i)(javaagent:|agentpath:|agentlib:)", RegexOptions.CultureInvariant)), "uninstall preserves user edits and removes only KnoxBridge args");

                var conflictGame = Path.Combine(temp, "conflict"); Directory.CreateDirectory(conflictGame);
                var conflictJson = Encoding.UTF8.GetBytes("{\"vmArgs\":[\"-agentlib:exampleRuntime\"]}");
                File.WriteAllBytes(Path.Combine(conflictGame, "ProjectZomboid64.json"), conflictJson);
                var blocked = false;
                try { InstallerCore.Install(conflictGame, payload); } catch (InvalidOperationException) { blocked = true; }
                Check(blocked && File.ReadAllBytes(Path.Combine(conflictGame, "ProjectZomboid64.json")).SequenceEqual(conflictJson), "competing runtime blocked without mutation");

                var tamperedGame = Path.Combine(temp, "tampered-state"); Directory.CreateDirectory(tamperedGame);
                File.WriteAllBytes(Path.Combine(tamperedGame, "ProjectZomboid64.json"), original);
                InstallerCore.Install(tamperedGame, payload);
                var statePath = Path.Combine(tamperedGame, ".knoxbridge", "install-state.json");
                var stateNode = JsonNode.Parse(File.ReadAllBytes(statePath))!.AsObject();
                stateNode["AgentArgument"] = "-Duser=must-not-be-removed";
                File.WriteAllText(statePath, stateNode.ToJsonString(JsonOptions));
                var tamperBlocked = false;
                try { InstallerCore.Uninstall(tamperedGame); } catch (InvalidDataException) { tamperBlocked = true; }
                var tamperedConfig = JsonNode.Parse(File.ReadAllBytes(Path.Combine(tamperedGame, "ProjectZomboid64.json")))!.AsObject();
                Check(tamperBlocked && tamperedConfig["vmArgs"]!.AsArray().Any(node => (node?.GetValue<string>() ?? "").StartsWith("-javaagent:")), "tampered ownership state cannot remove unrelated launcher arguments");

                Console.WriteLine("KnoxBridge native installer self-test PASS checks=8");
                return 0;
            }
            catch (Exception ex) { Console.Error.WriteLine($"KnoxBridge native installer self-test FAIL: {ex}"); return 1; }
            finally { try { Directory.Delete(temp, true); } catch { } }
        }

        private static void Check(bool condition, string description)
        {
            if (!condition) throw new InvalidOperationException("Self-test failed: " + description);
        }

        private static byte[] MakePackageArchive(byte[] agent, byte[] bootstrap, bool corruptChecksum)
        {
            using var output = new MemoryStream();
            using (var archive = new ZipArchive(output, ZipArchiveMode.Create, leaveOpen: true))
            {
                var agentName = "knoxbridge-agent-0.1.0-alpha7.jar";
                AddEntry(archive, agentName, agent);
                var agentHash = Convert.ToHexString(SHA256.HashData(corruptChecksum ? new byte[] { 0 } : agent)).ToLowerInvariant();
                AddEntry(archive, agentName + ".sha256", Encoding.ASCII.GetBytes(agentHash + "  " + agentName + "\n"));

                const string bootstrapName = "bootstrap-windows/knoxbridge-bootstrap.dll";
                AddEntry(archive, bootstrapName, bootstrap);
                var bootstrapHash = Convert.ToHexString(SHA256.HashData(bootstrap)).ToLowerInvariant();
                AddEntry(archive, bootstrapName + ".sha256", Encoding.ASCII.GetBytes(bootstrapHash + "  " + bootstrapName + "\n"));
            }
            return output.ToArray();
        }

        private static void AddEntry(ZipArchive archive, string name, byte[] bytes)
        {
            var entry = archive.CreateEntry(name);
            using var stream = entry.Open();
            stream.Write(bytes, 0, bytes.Length);
        }
    }
}
