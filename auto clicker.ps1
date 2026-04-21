Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    [DllImport("winmm.dll")]
    public static extern uint timeBeginPeriod(uint uPeriod);
    [DllImport("winmm.dll")]
    public static extern uint timeEndPeriod(uint uPeriod);
}
"@

# Prepare High-Precision Timing
[Win32]::timeBeginPeriod(1)
Add-Type -AssemblyName System.Windows.Forms

$clicking = $false
$lastTabState = 0
$totalClicks = 0

# --- CREATE THE GRAPHICAL BUTTON WINDOW ---
$form = New-Object Windows.Forms.Form
$form.Text = "CPS Tester"
$form.Size = "300,200"
$form.Topmost = $true
$form.StartPosition = "CenterScreen"

$btnTest = New-Object Windows.Forms.Button
$btnTest.Text = "CLICK FOR 5s TEST"
$btnTest.Size = "200,50"
$btnTest.Location = "45,20"
$btnTest.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

$lblStatus = New-Object Windows.Forms.Label
$lblStatus.Text = "TAB: Toggle Infinite | T: Key Test"
$lblStatus.Location = "45,80"
$lblStatus.Size = "200,40"
$lblStatus.TextAlign = "MiddleCenter"

$form.Controls.Add($btnTest)
$form.Controls.Add($lblStatus)

# --- THE ACTUAL CLICKING LOGIC ---
function Run-Test {
    $btnTest.Enabled = $false
    $script:totalClicks = 0
    $duration = 5
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($sw.Elapsed.TotalSeconds -lt $duration) {
        # Burst of 10 clicks
        for ($i=0; $i -lt 10; $i++) {
            # SECONDARY SAFETY: Check time inside the burst to stop INSTANTLY
            if ($sw.Elapsed.TotalSeconds -ge $duration) { break }
            [Win32]::mouse_event(0x0002, 0, 0, 0, 0)
            [Win32]::mouse_event(0x0004, 0, 0, 0, 0)
            $script:totalClicks++
        }
        
        # Only update the UI every 100 clicks to prevent LAG
        if ($totalClicks % 100 -eq 0) {
            $timeLeft = [math]::Max(0, [math]::Round($duration - $sw.Elapsed.TotalSeconds, 1))
            $btnTest.Text = "TIME: $timeLeft | CLICKS: $totalClicks"
            [System.Windows.Forms.Application]::DoEvents()
        }
        [System.Threading.Thread]::Sleep(1)
    }
    $sw.Stop()
    $btnTest.Text = "FINAL CPS: $($totalClicks / 5)"
    $lblStatus.Text = "Total Clicks: $totalClicks"
    Start-Sleep -Seconds 1
    $btnTest.Enabled = $true
}

# Attach the function to the button
$btnTest.Add_Click({ Run-Test })

# --- MAIN PROGRAM LOOP ---
Clear-Host
Write-Host "--- ULTIMATE CLICKER LOADED ---" -ForegroundColor Cyan
Write-Host "Window is open. Use Button, T key, or TAB."

$form.Show()

while ($form.Visible) {
    # Keeps the window alive
    [System.Windows.Forms.Application]::DoEvents()

    # 1. TAB TOGGLE (Infinite Mode)
    $tabState = [Win32]::GetAsyncKeyState(0x09)
    if (($tabState -band 0x8000) -and -not ($lastTabState -band 0x8000)) {
        $clicking = !$clicking
        if ($clicking) { $lblStatus.ForeColor = "Green"; $lblStatus.Text = "INFINITE: ON" }
        else { $lblStatus.ForeColor = "Black"; $lblStatus.Text = "INFINITE: OFF" }
    }
    $lastTabState = $tabState

    # 2. T KEY (Trigger the same test as the button)
    if ([Win32]::GetAsyncKeyState(0x54) -band 0x8000) {
        if ($btnTest.Enabled) { Run-Test }
    }

    # 3. EXIT (ESC)
    if ([Win32]::GetAsyncKeyState(0x1B) -band 0x8000) { $form.Close() }

    # 4. INFINITE CLICKING EXECUTION
    if ($clicking) {
        for ($i=0; $i -lt 10; $i++) {
            [Win32]::mouse_event(0x0002, 0, 0, 0, 0)
            [Win32]::mouse_event(0x0004, 0, 0, 0, 0)
        }
        [System.Threading.Thread]::Sleep(1)
    } else {
        [System.Threading.Thread]::Sleep(10) # Save CPU when idle
    }
}

[Win32]::timeEndPeriod(1)
Write-Host "Program Closed."