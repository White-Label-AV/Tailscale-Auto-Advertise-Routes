<#
.SYNOPSIS
    Tailscale Route Advertiser
.DESCRIPTION
    This script identifies all currently connected physical ethernet or wifi connections,
    allows the user to select one, and then connects to a tailscale tailnet advertising that route.
.NOTES
    Requires Tailscale to be installed on the system.
    Run with administrator privileges.
#>

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges. Please run as administrator." -ForegroundColor Red
    Write-Host "Right-click the script and select 'Run with PowerShell as administrator'." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit
}

# Check if Tailscale is installed
try {
    $tailscaleVersion = tailscale version
    Write-Host "Tailscale detected: $tailscaleVersion" -ForegroundColor Green
}
catch {
    Write-Host "Tailscale is not installed or not in PATH. Please install Tailscale first." -ForegroundColor Red
    Write-Host "Download from: https://tailscale.com/download" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit
}

# Get network connections (only physical Ethernet and WiFi)
function Get-PhysicalNetworkConnections {
    $connections = @()
    
    # Get all network adapters that are physical (Ethernet or WiFi) and connected
    $adapters = Get-NetAdapter | Where-Object {
        ($_.MediaType -eq "802.3" -or $_.MediaType -eq "Native 802.11") -and 
        $_.Status -eq "Up"
    }
    
    foreach ($adapter in $adapters) {
        # Get IP configuration for this adapter
        $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
        
        # Only include adapters with IPv4 addresses
        if ($ipConfig.IPv4Address) {
            $ipv4Address = $ipConfig.IPv4Address.IPAddress
            $ipv4Subnet = $ipConfig.IPv4Address.PrefixLength
            
            # Calculate the network address (for proper subnet format)
            $ipBytes = $ipv4Address.Split('.') | ForEach-Object { [byte]$_ }
            $maskBytes = @()
            $bitsLeft = $ipv4Subnet
            
            # Convert prefix length to subnet mask bytes
            for ($i = 0; $i -lt 4; $i++) {
                if ($bitsLeft -ge 8) {
                    $maskBytes += 255
                    $bitsLeft -= 8
                } elseif ($bitsLeft -gt 0) {
                    $maskBytes += (256 - [Math]::Pow(2, (8 - $bitsLeft)))
                    $bitsLeft = 0
                } else {
                    $maskBytes += 0
                }
            }
            
            # Apply mask to get network address
            $networkBytes = @()
            for ($i = 0; $i -lt 4; $i++) {
                $networkBytes += ($ipBytes[$i] -band $maskBytes[$i])
            }
            
            $networkAddress = $networkBytes -join '.'
            $subnet = "$networkAddress/$ipv4Subnet"
            
            # Also store the host address for display purposes
            $hostSubnet = "$ipv4Address/$ipv4Subnet"
            
            # Get gateway if available
            $gateway = "N/A"
            if ($ipConfig.IPv4DefaultGateway) {
                $gateway = $ipConfig.IPv4DefaultGateway.NextHop
            }
            
            # Determine connection type
            $connectionType = "WiFi"
            if ($adapter.MediaType -eq "802.3") {
                $connectionType = "Ethernet"
            }
            
            # Create custom object with connection details
            $connectionInfo = [PSCustomObject]@{
                Name = $adapter.Name
                InterfaceDescription = $adapter.InterfaceDescription
                Type = $connectionType
                Status = $adapter.Status
                IPAddress = $ipv4Address
                Subnet = $subnet
                Gateway = $gateway
                InterfaceIndex = $adapter.ifIndex
            }
            
            $connections += $connectionInfo
        }
    }
    
    return $connections
}

# Clear the console and show header
Clear-Host
Write-Host "=== Tailscale Route Advertiser ===" -ForegroundColor Cyan
Write-Host "This script will help you advertise a network route to your Tailscale tailnet."
Write-Host "This makes the selected network accessible to other devices in your tailnet."
Write-Host ""

# Get the network connections
$networkConnections = Get-PhysicalNetworkConnections

if ($networkConnections.Count -eq 0) {
    Write-Host "No active physical network connections found." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}

# Display available connections
Write-Host "Available Network Connections:" -ForegroundColor Green
Write-Host "-----------------------------"
for ($i = 0; $i -lt $networkConnections.Count; $i++) {
    $conn = $networkConnections[$i]
    Write-Host "[$($i+1)] $($conn.Name) ($($conn.Type))" -ForegroundColor Yellow
    Write-Host "    IP Address: $($conn.IPAddress)"
    Write-Host "    Network: $($conn.Subnet)"
    Write-Host "    Gateway: $($conn.Gateway)"
    Write-Host "    Description: $($conn.InterfaceDescription)"
    Write-Host ""
}

# Get user selection
$validSelection = $false
$selectedIndex = -1

while (-not $validSelection) {
    $selection = Read-Host "Enter the number of the connection you want to advertise [1-$($networkConnections.Count)]"
    
    if ($selection -match '^\d+$') {
        $selectedIndex = [int]$selection - 1
        
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $networkConnections.Count) {
            $validSelection = $true
        }
        else {
            Write-Host "Invalid selection. Please enter a number between 1 and $($networkConnections.Count)." -ForegroundColor Red
        }
    }
    else {
        Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
    }
}

$selectedConnection = $networkConnections[$selectedIndex]
Write-Host ""
Write-Host "Selected: $($selectedConnection.Name) - $($selectedConnection.Subnet)" -ForegroundColor Green
Write-Host ""

# Ask about exit node
$exitNode = $false
$exitNodeResponse = Read-Host "Do you want to advertise this machine as an exit node? (y/n)"
if ($exitNodeResponse -match '^[yY]') {
    $exitNode = $true
    Write-Host "This machine will be advertised as an exit node." -ForegroundColor Yellow
}

# Ask about auth key
$useAuthKey = $false
$authKey = ""
$authKeyResponse = Read-Host "Do you want to use an auth key? (y/n)"
if ($authKeyResponse -match '^[yY]') {
    $useAuthKey = $true
    $authKey = Read-Host "Enter your Tailscale auth key"
    Write-Host "Auth key will be used for authentication." -ForegroundColor Yellow
}

# Confirm before proceeding
Write-Host ""
Write-Host "Ready to advertise the following route to your Tailscale tailnet:" -ForegroundColor Cyan
Write-Host "  - Network: $($selectedConnection.Subnet)"
if ($exitNode) {
    Write-Host "  - This machine will be advertised as an exit node"
}
Write-Host ""
$confirmResponse = Read-Host "Proceed? (y/n)"

if ($confirmResponse -notmatch '^[yY]') {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit
}

# Execute the Tailscale command
Write-Host ""
Write-Host "Configuring Tailscale..." -ForegroundColor Blue

try {
    # Verify Tailscale is running
    try {
        $tailscaleStatus = tailscale status
        Write-Host "Tailscale is running." -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not verify Tailscale status. Continuing anyway..." -ForegroundColor Yellow
        Write-Host "Error details: $_" -ForegroundColor Gray
    }
    
    # Build the command based on user selections
    $command = "tailscale up"
    
    # Add route advertisement
    $command += " --advertise-routes=$($selectedConnection.Subnet)"
    
    # Add exit node if selected
    if ($exitNode) {
        $command += " --advertise-exit-node"
    }
    
    # Add auth key if provided
    if ($useAuthKey -and -not [string]::IsNullOrWhiteSpace($authKey)) {
        $command += " --authkey=********" # Mask the actual key in the displayed command
    }
    
    # Execute the command
    Write-Host "Executing: $command" -ForegroundColor Gray
    
    # Use Start-Process for better error capture
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    # Build argument list properly
    $argList = @("up", "--advertise-routes=$($selectedConnection.Subnet)")
    if ($exitNode) {
        $argList += "--advertise-exit-node"
    }
    if ($useAuthKey -and -not [string]::IsNullOrWhiteSpace($authKey)) {
        $argList += "--authkey=$authKey"
    }
    
    $process = Start-Process -FilePath "tailscale" -ArgumentList $argList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempFile -RedirectStandardError "$tempFile.err"
    $output = Get-Content -Path $tempFile -Raw
    $errorOutput = Get-Content -Path "$tempFile.err" -Raw -ErrorAction SilentlyContinue
    
    # Display the output
    if (-not [string]::IsNullOrWhiteSpace($output)) {
        Write-Host "Command output:" -ForegroundColor Gray
        Write-Host $output
    }
    
    # Display any error output
    if (-not [string]::IsNullOrWhiteSpace($errorOutput)) {
        Write-Host "Error output:" -ForegroundColor Red
        Write-Host $errorOutput
    }
    
    # Check if successful
    if ($process.ExitCode -eq 0) {
        Write-Host "Success! Route $($selectedConnection.Subnet) has been advertised to your tailnet." -ForegroundColor Green
        
        # Add note about approval if needed
        if ($output -match "approval" -or $errorOutput -match "approval") {
            Write-Host "Note: The route is waiting for approval from your tailnet admin." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Error: Tailscale command failed with exit code $($process.ExitCode)" -ForegroundColor Red
        
        # Provide troubleshooting guidance
        Write-Host ""
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Make sure you're logged into Tailscale (run 'tailscale status' to check)" -ForegroundColor Yellow
        Write-Host "2. Verify that your Tailscale account has permissions to advertise routes" -ForegroundColor Yellow
        Write-Host "3. Check if your tailnet has subnet routing enabled in the admin console" -ForegroundColor Yellow
        Write-Host "4. Try running the command manually: $command" -ForegroundColor Yellow
    }
    
    # Clean up temp files
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$tempFile.err" -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "Error executing Tailscale command: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
