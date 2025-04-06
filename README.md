# 🛡️ tiux - sudo but built for Windows

tiux is a PowerShell-based, sudo-like tool that lets you run any application or command with **TrustedInstaller** privileges on Windows. This is especially useful for advanced system tasks that even Administrator accounts cannot perform directly.

---

## ✨ Features

- 🚀 **Launch any executable** as TrustedInstaller  
- 🖥️ Supports both GUI and CLI tools  
- 🔄 Automatically handles the TrustedInstaller service  
- 📝 Simple, safe, and transparent logging

---

## 📅 Installation

### Prerequisites

- Windows 10 or newer  
- PowerShell 5.1+  
- Administrator privileges  
- Internet connection (for first-time module installation)

### Steps

1. **Open PowerShell as Administrator.**
2. Run the following command to download and install tiux:

    ```powershell
    irm https://raw.githubusercontent.com/fynrae/tiux/main/tiux-install.ps1 | iex
    ```

This command will:
- Create the installation directory at `C:\Program Files\tiux`
- Write the `tiux.ps1` and `untrusted1nstaller-runas.ps1` scripts  
- Create `.cmd` shims so you can launch `tiux` from any terminal  
- Add the install directory to your system PATH (if not already present)

---

## 🚀 Usage

tiux is used from the command line like any normal Windows command.

### Basic Usage

```bash
tiux notepad
```
*Launches Notepad with TrustedInstaller privileges.*

```bash
tiux cmd
```
*Opens a new Command Prompt session as TrustedInstaller.*

### Custom Executables

```bash
tiux "C:\Path\To\YourApp.exe" arg1 arg2
```
Pass full paths and arguments as you would in a normal terminal. If the path contains spaces, wrap it in quotes.

### Version Check

```bash
tiux --version
```
*Displays the installed version.*

---

## ⚙️ How It Works

1. **Restarts** the TrustedInstaller service and retrieves its PID  
2. Uses the **NtObjectManager** module to impersonate the TrustedInstaller process  
3. **Launches** the specified executable using `New-Win32Process` under that context

_All operations are logged to `%TEMP%\tiux-log.txt`_

---

## 🔍 Troubleshooting

- **File not found**: Ensure the executable exists or is in your system PATH  
- **Permissions error**: Make sure you're running the command as Administrator  
- **Module not found**: If `NtObjectManager` fails to install, check your internet connection or run:

    ```powershell
    Install-Module NtObjectManager -Scope CurrentUser -Force -SkipPublisherCheck
    ```

---

## 🙏 Credits

Developed by [Fynrae](https://github.com/fynrae)

Related tools: [untrusted1nstaller](https://github.com/fynrae/untrusted1nstaller)

