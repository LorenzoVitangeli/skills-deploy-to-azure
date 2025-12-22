param(
    [string]$VMAdminUsername,
    [string]$AdminPassword,
    [string]$Organization,
    [string]$Token,
    [int]$Count,
    [string]$AgentUrl,
    [string]$FinalSetupScriptUrl,
    [string]$Pool,
    [string]$VMName
)

Write-Host "=== INIT BUILD AGENT SCRIPT STARTED ==="

# Convert password
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUsername, $SecurePassword)

# Create base folder
$BaseFolder = "C:\BuildAgents"
if (!(Test-Path $BaseFolder)) {
    New-Item -ItemType Directory -Path $BaseFolder | Out-Null
}

# Install PowerShell 7
Write-Host "Installing PowerShell 7..."
Invoke-WebRequest -Uri "https://aka.ms/install-powershell.ps1" -OutFile "$BaseFolder\install-pwsh.ps1"
powershell.exe -ExecutionPolicy Bypass -File "$BaseFolder\install-pwsh.ps1" -UseMSI

# Install Git
Write-Host "Installing Git..."
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe" -OutFile "$BaseFolder\git.exe"
Start-Process "$BaseFolder\git.exe" -ArgumentList "/VERYSILENT" -Wait

# Download agent package
Write-Host "Downloading GitHub runner..."
$RunnerZip = "$BaseFolder\runner.zip"
Invoke-WebRequest -Uri $AgentUrl -OutFile $RunnerZip

# Create agents
for ($i = 1; $i -le $Count; $i++) {

    $AgentFolder = "$BaseFolder\agent$i"
    if (!(Test-Path $AgentFolder)) {
        New-Item -ItemType Directory -Path $AgentFolder | Out-Null
    }

    Write-Host "Extracting runner $i..."
    Expand-Archive -Path $RunnerZip -DestinationPath $AgentFolder -Force

    Write-Host "Configuring runner $i..."
    Set-Location $AgentFolder

    .\config.cmd --unattended `
        --url $Organization `
        --token $Token `
        --name "$VMName-agent$i" `
        --work "_work" `
        --labels "$Pool" `
        --runasservice

    Write-Host "Installing service for runner $i..."
    .\svc install
    .\svc start
}

# Run final setup script if provided
if ($FinalSetupScriptUrl -and $FinalSetupScriptUrl -ne "") {
    Write-Host "Running final setup script..."
    $FinalScript = "$BaseFolder\final.ps1"
    Invoke-WebRequest -Uri $FinalSetupScriptUrl -OutFile $FinalScript
    powershell.exe -ExecutionPolicy Bypass -File $FinalScript
}

Write-Host "=== INIT BUILD AGENT SCRIPT COMPLETED ==="