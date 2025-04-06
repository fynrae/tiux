# 🛡️ tiux: Run Programs as TrustedInstaller

`tiux` is a command-line tool that allows you to run any executable as the **TrustedInstaller** user on Windows. This can be useful for managing protected system files or bypassing certain access control restrictions (for advanced users).

---

## 📦 Features

- 🧠 Automatically elevates privileges to TrustedInstaller
- 🔒 Works with UAC and NTObjectManager
- 📝 Generates logs in `%TEMP%`
- ⚙️ Simple command-line interface like `sudo`

---

## 📥 Installation

> ⚠️ **Requires Administrator Privileges**

1. **Download or clone this repository.**
2. Open **PowerShell as Administrator**.
3. Run the installer script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.	iux-install.ps1
```

This will:
- Create `C:\Program Files\tiux\scripts\tiux.ps1`
- Create `C:\Program Files\tiux\tiux.cmd` shim
- Add `C:\Program Files\tiux` to your `PATH` (if not already)

---

## 🚀 Usage

After installation, you can run programs as TrustedInstaller using:

```bash
tiux notepad.exe
```

You can also pass full paths or command-line arguments:

```bash
tiux "C:\Windows\System32\cmd.exe" /k whoami
```

### 🔍 Check Version
```bash
tiux --version
```

---

## 🧪 Testing

To verify it works:

1. Run:
   ```bash
   tiux cmd.exe
   ```

2. In the new CMD window, run:
   ```cmd
   whoami
   ```
   You should see:
   ```
   nt authority\system
   ```

3. Try editing a protected file:
   ```bash
   tiux notepad "C:\Windows\System32\drivers\etc\hosts"
   ```

---

## 🧼 Uninstalling

To remove `tiux`, manually delete:

- `C:\Program Files\tiux`
- Remove it from your system `PATH`

---

## 🛠️ Troubleshooting

### ❌ "Please run this script as Administrator!"
Make sure you're running the PowerShell script with **Run as Administrator**.

### ❌ `NtObjectManager` module issues
Run this to install it manually:
```powershell
Install-Module NtObjectManager -Scope CurrentUser -Force -SkipPublisherCheck
```

---

## 🙏 Credits

- ⚙️ [NtObjectManager](https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools) by James Forshaw
- 🧠 Inspired by Linux's `sudo`, but for Windows TrustedInstaller use

---

## 🧙‍♂️ Advanced Usage

`tiux` can be used to script or automate tasks needing elevated privileges beyond Administrator. Be cautious — you can make system-wide changes.

```bash
tiux powershell.exe -Command "Remove-Item -Force C:\Windows\System32\somefile.dll"
```

---

## 📬 Feedback
Have suggestions, issues, or ideas? Feel free to open an issue or contribute!

Happy hacking with ✨ `tiux`!

