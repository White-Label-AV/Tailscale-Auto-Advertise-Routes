# Tailscale Route Advertiser

This tool allows you to easily advertise routes from your Windows device to your Tailscale tailnet. It provides a simple console-based interface to select which network connection you want to share with other devices in your tailnet.

## Prerequisites

- Windows 10 or 11
- [Tailscale](https://tailscale.com/download) installed and configured
- PowerShell 5.1 or later (included with Windows 10/11)
- Administrator privileges

## Features

- Automatically detects all active Ethernet and WiFi connections
- Displays detailed information about each connection (IP address, subnet, gateway)
- Option to advertise your device as an exit node (allows other devices to use your internet connection)
- Support for Tailscale auth keys for automated/unattended setup
- Clear, step-by-step console interface

## How to Use

There are three ways to run the script:

### Option 1: One-Line Web Installation (Recommended)

Run the following command in an administrator PowerShell window:

```powershell
irm tailscale.whitelabelav.co.nz | iex
```

This will download and run the script directly from the web in a single command.

### Option 2: Using the separate batch file

1. Download both `TailscaleRouteAdvertiser.ps1` and `RunTailscaleRouteAdvertiser.bat`
2. Double-click the `RunTailscaleRouteAdvertiser.bat` file
3. When prompted by User Account Control, click "Yes" to allow the script to run with administrator privileges
4. Follow the on-screen prompts in the PowerShell window that appears

### Option 3: Running the PowerShell script directly

1. Download the `TailscaleRouteAdvertiser.ps1` script
2. Right-click the script and select "Run with PowerShell as administrator"
3. Follow the on-screen prompts

### Using the Script

Once the script is running:
1. Select a network connection by entering its number
2. Choose whether to advertise as an exit node (y/n)
3. Confirm your selections
4. The script will execute the Tailscale command and display the results

## Notes

- Route advertisements may require approval from your tailnet administrator
- The script automatically checks if Tailscale is installed
- For security reasons, the script must be run with administrator privileges

## Troubleshooting

If you encounter issues when running the script:

- **Tailscale not found**: Make sure Tailscale is installed and in your PATH
- **Permission issues**: Verify you're running the script as administrator
- **No connections shown**: Check that you have active network connections
- **Command fails**: The script will now provide detailed error output and troubleshooting tips

Common Tailscale-specific issues:

1. **Not logged in**: Run `tailscale status` to verify you're logged into Tailscale
2. **Permission issues**: Ensure your Tailscale account has permissions to advertise routes
3. **Subnet routing disabled**: Check if subnet routing is enabled in your tailnet admin console
4. **Exit node restrictions**: Some tailnets restrict who can advertise exit nodes

The script includes improved error handling that will display:
- Detailed command output
- Error messages from Tailscale
- Exit codes
- Specific troubleshooting suggestions

## How It Works

The script uses PowerShell's networking cmdlets to identify physical network connections, then uses the Tailscale CLI to advertise the selected route to your tailnet. The console-based interface makes it easy to select which connection to share while keeping the tool lightweight and simple.
