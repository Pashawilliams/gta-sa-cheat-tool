# Temporary interactive test desktop

This workflow is exclusively for a single developer to test this repository's Grove Codes application. It is not a general-purpose cloud PC, VPS, game server or permanent hosting service. Follow GitHub's Actions terms. There is no automatic restart or scheduling.

- Real Windows Server 2022, **not Windows 10**.
- TightVNC on loopback only, password authentication required.
- noVNC / Websockify on loopback, forwarded through an HTTPS Cloudflare Quick Tunnel.
- The URL is public in the Actions summary; the desktop password is a separate Actions secret.
- Set `DESKTOP_PASSWORD` to 8 independently random ASCII letters/digits (VNC's password length limit). Change it before a new session; do not reuse any personal password.
- The VNC authentication and framebuffer are checked before the tunnel starts.
- Only one client at a time. No unauthenticated VNC or firewall exception is enabled. Windows Defender is not disabled.
- Browser-to-tunnel transport is encrypted, but this is not an enterprise remote desktop gateway. Do not enter personal credentials, private files or cloud accounts on the machine.
- TightVNC file transfers are disabled. The runner, installed programs and application files are destroyed when the job ends.
- The reviewed v1.0.0 GroveCodes.exe is downloaded to the desktop and its exact SHA-256 is checked.
- Workflow stops after a 30-minute test window, with a 40-minute job hard limit. Cancel the run to stop early.
- No GTA is installed. This can test the helper UI but cannot establish in-game cheat compatibility.
- Public tunnel availability is not guaranteed. Quick Tunnels are for temporary testing.

To launch: repository Actions → Temporary interactive Grove Codes test → Run workflow. Open the URL in the job summary and enter the private VNC password when prompted. Do not put passwords into URLs or commit them to Git.
