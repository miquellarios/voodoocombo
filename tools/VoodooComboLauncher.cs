using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("VoodooCombo 0.1")]
[assembly: AssemblyProduct("VoodooCombo")]
[assembly: AssemblyCompany("VoodooCombo")]
[assembly: AssemblyVersion("0.1.0.0")]
[assembly: AssemblyFileVersion("0.1.0.0")]
[assembly: AssemblyInformationalVersion("0.1")]

internal static class VoodooComboLauncher
{
	[STAThread]
	private static int Main(string[] args)
	{
		string folder = AppDomain.CurrentDomain.BaseDirectory;
		string engine = Path.Combine(folder, "Godot_v4.7.2-stable_win64_console.exe");
		string pack = Path.Combine(folder, "VoodooCombo-0.1.pck");
		if (!File.Exists(engine) || !File.Exists(pack))
		{
			MessageBox.Show("Mantén VoodooCombo-0.1.pck y Godot_v4.7.2-stable_win64_console.exe junto a este ejecutable.", "VoodooCombo 0.1", MessageBoxButtons.OK, MessageBoxIcon.Error);
			return 1;
		}
		ProcessStartInfo start = new ProcessStartInfo();
		start.FileName = engine;
		start.WorkingDirectory = folder;
		start.UseShellExecute = false;
		start.CreateNoWindow = true;
		start.Arguments = "--main-pack " + Quote(pack);
		foreach (string arg in args)
			start.Arguments += " " + Quote(arg);
		try
		{
			using (Process game = Process.Start(start))
			{
				game.WaitForExit();
				return game.ExitCode;
			}
		}
		catch (Exception error)
		{
			MessageBox.Show(error.Message, "VoodooCombo 0.1", MessageBoxButtons.OK, MessageBoxIcon.Error);
			return 1;
		}
	}

	private static string Quote(string value)
	{
		return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
	}
}
