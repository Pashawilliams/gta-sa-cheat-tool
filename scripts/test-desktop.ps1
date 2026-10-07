# Temporary, single-user interactive testing of Grove Codes only.
$ErrorActionPreference = 'Stop'
if ($env:DESKTOP_PASSWORD -notmatch '^[A-Za-z0-9]{8}$') { throw 'Set DESKTOP_PASSWORD to exactly 8 random letters/digits in repository Actions secrets.' }
$privatePassword = $env:DESKTOP_PASSWORD
$work = Join-Path $env:RUNNER_TEMP 'grove-test-desktop'
New-Item -ItemType Directory -Force $work | Out-Null
Set-Location $work
Invoke-WebRequest 'https://www.tightvnc.com/download/2.8.85/tightvnc-2.8.85-gpl-setup-64bit.msi' -OutFile tightvnc.msi
if ((Get-AuthenticodeSignature .\tightvnc.msi).Status -ne 'Valid') { throw 'TightVNC installer signature is invalid' }
$argsList = @('/i', "$work\tightvnc.msi", '/quiet', '/norestart', 'ADDLOCAL=Server',
 'SERVER_REGISTER_AS_SERVICE=1','SERVER_ADD_FIREWALL_EXCEPTION=0',
 'SET_ACCEPTHTTPCONNECTIONS=1','VALUE_OF_ACCEPTHTTPCONNECTIONS=0',
 'SET_ALLOWLOOPBACK=1','VALUE_OF_ALLOWLOOPBACK=1',
 'SET_LOOPBACKONLY=1','VALUE_OF_LOOPBACKONLY=1',
 'SET_USEVNCAUTHENTICATION=1','VALUE_OF_USEVNCAUTHENTICATION=1',
 'SET_PASSWORD=1',"VALUE_OF_PASSWORD=$privatePassword",
 'SET_USECONTROLAUTHENTICATION=1','VALUE_OF_USECONTROLAUTHENTICATION=1',
 'SET_CONTROLPASSWORD=1',"VALUE_OF_CONTROLPASSWORD=$privatePassword",
 'SET_NEVERSHARED=1','VALUE_OF_NEVERSHARED=1',
 'SET_DISCONNECTCLIENTS=1','VALUE_OF_DISCONNECTCLIENTS=0')
$installer = Start-Process msiexec.exe -ArgumentList $argsList -Wait -PassThru
if ($installer.ExitCode -notin @(0,3010)) { throw "TightVNC installation failed: $($installer.ExitCode)" }
New-ItemProperty 'HKLM:\SOFTWARE\TightVNC\Server' -Name EnableFileTransfers -PropertyType DWord -Value 0 -Force | Out-Null
Restart-Service tvnserver
python -m pip install --disable-pip-version-check 'websockify==0.13.0' 'pycryptodome==3.23.0'
if ($LASTEXITCODE -ne 0) { throw 'Python dependency installation failed' }
# Test an authenticated RFB handshake BEFORE exposing any public endpoint.
@'
import socket,os,struct
from Crypto.Cipher import DES
s=socket.create_connection(('127.0.0.1',5900),timeout=15)
def read(n):
    b=b''
    while len(b)<n:
        c=s.recv(n-len(b))
        if not c: raise RuntimeError('VNC connection closed')
        b+=c
    return b
version=read(12)
assert version.startswith(b'RFB '),version
s.sendall(b'RFB 003.008\n')
types=read(read(1)[0]);assert 2 in types and 1 not in types,'VNC must require password'
s.sendall(b'\x02')
challenge=read(16)
key=bytes(int(f'{x:08b}'[::-1],2) for x in os.environ['DESKTOP_PASSWORD'].encode())
s.sendall(DES.new(key,DES.MODE_ECB).encrypt(challenge))
assert struct.unpack('>I',read(4))[0]==0,'VNC authentication failed'
s.sendall(b'\x01');header=read(24);width,height=struct.unpack('>HH',header[:4])
assert width>0 and height>0
print(f'Authenticated Windows framebuffer: {width} x {height}')
s.close()
'@ | Set-Content -Encoding utf8 verify_vnc.py
python verify_vnc.py
if ($LASTEXITCODE -ne 0) { throw 'VNC authentication or framebuffer check failed' }
Remove-Item Env:\DESKTOP_PASSWORD
$privatePassword = $null
$argsList = $null
Invoke-WebRequest 'https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.zip' -OutFile novnc.zip
Expand-Archive novnc.zip -DestinationPath . -Force
Invoke-WebRequest 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile cloudflared.exe
if ((Get-AuthenticodeSignature .\cloudflared.exe).Status -ne 'Valid') { throw 'Cloudflared signature is invalid' }
$desktop = [Environment]::GetFolderPath('Desktop')
$exe = Join-Path $desktop 'GroveCodes.exe'
Invoke-WebRequest 'https://github.com/Pashawilliams/gta-sa-cheat-tool/releases/download/v1.0.0/GroveCodes.exe' -OutFile $exe
if ((Get-FileHash $exe -Algorithm SHA256).Hash.ToLower() -ne 'f235cfc575d0064701568f4c950a6133734dbe5632c2b1df1f26d3d418874efd') { throw 'Unexpected Grove Codes binary' }
'Temporary Grove Codes test desktop. Do not enter personal accounts or credentials. No GTA is installed. The session and files are deleted automatically. Close the GitHub Actions run to stop early.' | Set-Content (Join-Path $desktop 'READ-ME.txt')
Start-Process $exe | Out-Null
$python = (Get-Command python).Source
Start-Process $python -ArgumentList @('-m','websockify','--web',"$work\noVNC-1.6.0",'127.0.0.1:6080','127.0.0.1:5900') -RedirectStandardOutput proxy.out -RedirectStandardError proxy.err | Out-Null
for ($i=0;$i -lt 30;$i++) {
  try { $response=Invoke-WebRequest 'http://127.0.0.1:6080/vnc.html' -TimeoutSec 2; if($response.StatusCode -eq 200){break} } catch { Start-Sleep -Seconds 1 }
}
if (-not $response -or $response.StatusCode -ne 200) { Get-Content proxy.err; throw 'noVNC HTTP endpoint not ready' }
$tunnelProcess = Start-Process "$work\cloudflared.exe" -PassThru -ArgumentList @('tunnel','--url','http://127.0.0.1:6080','--no-autoupdate','--protocol','http2') -RedirectStandardOutput tunnel.out -RedirectStandardError tunnel.err
$url=$null
for ($i=0;$i -lt 60;$i++) {
  Start-Sleep -Seconds 1
  $text=Get-Content tunnel.err -Raw -ErrorAction SilentlyContinue
  if ($text -match 'https://[a-z0-9-]+\.trycloudflare\.com') { $url=$Matches[0]; break }
}
if (-not $url) { Get-Content tunnel.err; throw 'No public tunnel URL was assigned' }
$publicReady=$false
for ($i=0;$i -lt 45;$i++) {
  if ($tunnelProcess.HasExited) { Get-Content tunnel.err; throw "Tunnel exited: $($tunnelProcess.ExitCode)" }
  try { $test=Invoke-WebRequest "$url/vnc.html" -TimeoutSec 5; if ($test.StatusCode -eq 200) {$publicReady=$true;break} } catch { Start-Sleep -Seconds 2 }
}
Get-Content tunnel.err
if (-not $publicReady) { throw 'External tunnel HTTP check failed' }
$browserUrl = "$url/vnc.html?autoconnect=true&resize=scale&shared=false"
$evidence=Join-Path $env:GITHUB_WORKSPACE 'desktop-connection'
New-Item -ItemType Directory -Force $evidence | Out-Null
@{url=$browserUrl; purpose='Single-user interactive testing of Grove Codes'; os='Windows Server 2022'; readyUtc=[DateTime]::UtcNow.ToString('o'); maximumSessionMinutes=30; password='Use the private DESKTOP_PASSWORD secret; never put it in the URL'} | ConvertTo-Json | Set-Content "$evidence\connection.json"
"## Temporary Grove Codes test desktop`n`n[Open browser desktop]($browserUrl)`n`nRequires the private VNC password. Windows Server 2022; not Windows 10. Ends automatically after 30 minutes. Do not enter personal credentials. Cancel this workflow to stop immediately." | Out-File $env:GITHUB_STEP_SUMMARY -Append
Write-Host "GROVE_DESKTOP_URL=$browserUrl"
