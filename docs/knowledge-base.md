# Knowledge Base: 10 Common Windows Support Issues

Each article follows the same format: **Symptom, Likely cause, Diagnose, Fix, Prevent**.
Where possible, the toolkit scripts are used to diagnose or fix the problem.

---

## KB-01: PC is running slow
- **Symptom:** Apps take long to open, the fan is loud, the mouse lags.
- **Likely cause:** High memory or CPU use, too many startup programs, nearly full disk.
- **Diagnose:** Run `.\scripts\Get-HealthReport.ps1` and read the CPU, memory, and top-5 process sections.
- **Fix:**
  1. Close or end the top memory-using process in Task Manager (Ctrl+Shift+Esc).
  2. Task Manager > Startup apps > disable unneeded ones.
  3. Restart the PC if uptime is many days.
- **Prevent:** Restart weekly and keep startup apps minimal.
- **Verified:** Tested on Windows 11. Get-HealthReport.ps1 flagged high memory use (91%) and listed the top programs; Task Manager (Processes sorted by Memory) showed [WRITE THE TOP 3 PROGRAMS YOU SAW], and Startup apps listed [NUMBER] high-impact items.

## KB-02: Disk is almost full
- **Symptom:** "Low disk space" warning, updates fail, apps crash.
- **Likely cause:** Temp files, old downloads, large unused apps.
- **Diagnose:** `Get-HealthReport.ps1` shows disk used % (flagged at 90% or more).
- **Fix:**
  1. Run `.\scripts\Invoke-Cleanup.ps1 -WhatIf` to preview, then run it without `-WhatIf`.
  2. Settings > System > Storage > Temporary files > Remove.
  3. Uninstall apps that are not used and empty the Recycle Bin.
- **Prevent:** Keep at least 15% of the disk free.

## KB-03: Wi-Fi connected but no internet
- **Symptom:** Wi-Fi icon shows connected, pages do not load.
- **Likely cause:** Router/ISP issue, IP lease problem, or DNS failure.
- **Diagnose:** Run `.\scripts\Test-NetworkHealth.ps1` and read the DIAGNOSIS line.
- **Fix:**
  1. If the router is unreachable: restart the router, then `ipconfig /release` and `ipconfig /renew`.
  2. If the router works but the internet does not: restart the router or contact the ISP.
  3. If only DNS fails: see KB-04.
- **Prevent:** Restart the router periodically; keep adapter drivers updated.
- **Verified:** Tested on Windows 11. ipconfig /all showed the IPv4 address, default gateway and DNS server (the home router acted as gateway, DHCP server and DNS server), and Test-NetworkHealth.ps1 passed all four checks on this connection. Simulated DNS and internet failures were diagnosed correctly.

## KB-04: Websites do not open by name but ping works
- **Symptom:** `ping 8.8.8.8` works, `ping google.com` fails.
- **Likely cause:** DNS server not responding or a bad cache.
- **Diagnose:** `Test-NetworkHealth.ps1` reports "Internet works but DNS is failing".
- **Fix:**
  1. `ipconfig /flushdns` (or run `Invoke-Cleanup.ps1`, which flushes DNS).
  2. Set the DNS server to 8.8.8.8 in the adapter's IPv4 properties.
- **Prevent:** Use a reliable secondary DNS server.
- **Verified:** Tested on Windows 11. ping 8.8.8.8 succeeded (0% loss), nslookup resolved google.com and returned "Non-existent domain"      for an invalid name, and ipconfig /flushdns completed successfully.

## KB-05: Cannot connect to Wi-Fi
- **Symptom:** The network is not listed, or connecting fails repeatedly.
- **Likely cause:** Airplane mode, wrong saved credentials, outdated or faulty driver.
- **Diagnose:** `Test-NetworkHealth.ps1` reports "not connected to a network".
- **Fix:**
  1. Turn off airplane mode, toggle Wi-Fi off and on.
  2. Settings > Network > Wi-Fi > Manage known networks > Forget, then reconnect.
  3. Update or roll back the Wi-Fi driver in Device Manager.
  4. As administrator: `netsh winsock reset`, then restart.
- **Prevent:** Keep drivers updated through Windows Update.

## KB-06: Printer is not printing
- **Symptom:** Jobs stay in the queue or the printer shows "offline".
- **Likely cause:** Stuck print job or the Print Spooler service has stopped.
- **Diagnose:** Check the queue; `Get-Service Spooler` shows the service status.
- **Fix:**
  1. Run PowerShell as Administrator and run `.\scripts\Invoke-Cleanup.ps1 -ServiceName Spooler`.
  2. If a job is still stuck: stop the Spooler, clear `C:\Windows\System32\spool\PRINTERS`, start the Spooler.
  3. Remove and re-add the printer if needed.
- **Prevent:** Avoid sending very large jobs to a printer that is offline.

## KB-07: Application not responding or crashing
- **Symptom:** The window freezes or the app closes unexpectedly.
- **Likely cause:** Corrupt app files, low memory, or an incompatible update.
- **Diagnose:** Check memory with `Get-HealthReport.ps1`; check Event Viewer > Windows Logs > Application for the error.
- **Fix:**
  1. End the task in Task Manager and reopen the app.
  2. Update or repair the app (Settings > Apps > Installed apps > Modify/Repair).
  3. Reinstall if the problem continues.
- **Prevent:** Keep apps updated and keep free memory available.

## KB-08: User forgot password or account is locked
- **Symptom:** Cannot sign in; "account locked" message.
- **Likely cause:** Forgotten password or too many wrong attempts.
- **Diagnose:** Confirm the identity of the user and the type of account (local, Microsoft, or company domain).
- **Fix:**
  1. Microsoft account: use the account recovery page.
  2. Company/domain account: a helpdesk or admin resets the password and unlocks the account in Active Directory Users and Computers, and asks the user to change it at next sign-in.
  3. Local account: sign in as another admin and reset the password.
- **Prevent:** Set up self-service password reset and recovery options.

## KB-09: Windows Update fails or is stuck
- **Symptom:** Update stays at a percentage or reports an error code.
- **Likely cause:** Low disk space or a stuck update service.
- **Diagnose:** Check free disk space with `Get-HealthReport.ps1`; Settings > Windows Update > Update history.
- **Fix:**
  1. Free space (KB-02).
  2. Run Settings > System > Troubleshoot > Other troubleshooters > Windows Update.
  3. Restart the service (as admin): `.\scripts\Invoke-Cleanup.ps1 -ServiceName wuauserv`, then retry.
- **Prevent:** Keep at least 15% disk space free and restart after updates.

## KB-10: Blue screen or unexpected restarts
- **Symptom:** A blue screen with a stop code, or the PC restarts without warning.
- **Likely cause:** Faulty driver, corrupt system files, overheating or hardware faults.
- **Diagnose:** Note the stop code; check Event Viewer > Windows Logs > System around the time of the crash.
- **Fix:**
  1. Update or roll back the most recently changed driver.
  2. As administrator: `sfc /scannow`, then `chkdsk`.
  3. Check temperatures and test memory if crashes continue.
- **Prevent:** Install drivers only from trusted sources; keep the PC well ventilated.
