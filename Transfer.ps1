Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$script:proc  = $null
$script:timer = $null

$form = New-Object Windows.Forms.Form
$form.Text = "USB File Transfer - SEND"
$form.Size = New-Object Drawing.Size(650,470)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [Drawing.Color]::FromArgb(245,248,252)
$form.Font = New-Object Drawing.Font("Segoe UI",10)

$title = New-Object Windows.Forms.Label
$title.Text = "USB FILE TRANSFER"
$title.Font = New-Object Drawing.Font("Segoe UI",20,[Drawing.FontStyle]::Bold)
$title.Location = New-Object Drawing.Point(25,20)
$title.Size = New-Object Drawing.Size(580,40)
$form.Controls.Add($title)

$send = New-Object Windows.Forms.RadioButton
$send.Text = "SEND (PC to USB)"
$send.Location = New-Object Drawing.Point(30,85)
$send.Size = New-Object Drawing.Size(200,30)
$send.Checked = $true
$form.Controls.Add($send)

$receive = New-Object Windows.Forms.RadioButton
$receive.Text = "RECEIVE (USB to PC)"
$receive.Location = New-Object Drawing.Point(280,85)
$receive.Size = New-Object Drawing.Size(230,30)
$form.Controls.Add($receive)

function Add-FolderRow($labelText,$y) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $labelText
    $label.Location = New-Object Drawing.Point(30,$y)
    $label.Size = New-Object Drawing.Size(560,25)
    $form.Controls.Add($label)

    $box = New-Object Windows.Forms.TextBox
    $box.Location = New-Object Drawing.Point(30,($y+28))
    $box.Size = New-Object Drawing.Size(450,28)
    $form.Controls.Add($box)

    $button = New-Object Windows.Forms.Button
    $button.Text = "Browse..."
    $button.Location = New-Object Drawing.Point(490,($y+26))
    $button.Size = New-Object Drawing.Size(100,30)
    $form.Controls.Add($button)

    $button.Add_Click({
        $dialog = New-Object Windows.Forms.FolderBrowserDialog
        $dialog.ShowNewFolderButton = $true
        if ($dialog.ShowDialog() -eq "OK") { $box.Text = $dialog.SelectedPath }
    }.GetNewClosure())

    return @{ Box = $box; Label = $label }
}

$srcRow = Add-FolderRow "SOURCE FOLDER (on PC)" 135
$dstRow = Add-FolderRow "DESTINATION FOLDER (on USB)" 220
$source = $srcRow.Box
$destination = $dstRow.Box

$status = New-Object Windows.Forms.Label
$status.Text = "Ready to transfer files."
$status.Location = New-Object Drawing.Point(30,295)
$status.Size = New-Object Drawing.Size(560,25)
$form.Controls.Add($status)

$progress = New-Object Windows.Forms.ProgressBar
$progress.Location = New-Object Drawing.Point(30,325)
$progress.Size = New-Object Drawing.Size(560,18)
$progress.Style = "Marquee"
$progress.MarqueeAnimationSpeed = 0
$form.Controls.Add($progress)

$start = New-Object Windows.Forms.Button
$start.Text = "START TRANSFER"
$start.Location = New-Object Drawing.Point(30,360)
$start.Size = New-Object Drawing.Size(180,38)
$start.BackColor = [Drawing.Color]::FromArgb(30,120,210)
$start.ForeColor = [Drawing.Color]::White
$start.FlatStyle = "Flat"
$form.Controls.Add($start)

$cancel = New-Object Windows.Forms.Button
$cancel.Text = "CANCEL"
$cancel.Location = New-Object Drawing.Point(225,360)
$cancel.Size = New-Object Drawing.Size(120,38)
$cancel.Enabled = $false
$form.Controls.Add($cancel)

function Stop-Transfer {
    if ($script:timer) { $script:timer.Stop() }
    if ($script:proc -and -not $script:proc.HasExited) {
        # kill robocopy and any child processes
        & taskkill.exe /PID $script:proc.Id /T /F | Out-Null
    }
}

function Quote-Path($p) {
    # Safe quoting for robocopy: handles trailing backslash and drive roots like E:\
    return '"' + $p.TrimEnd('\') + '\\"'
}

$start.Add_Click({
    $src = $source.Text.Trim()
    $dst = $destination.Text.Trim()

    if (!(Test-Path -LiteralPath $src -PathType Container)) {
        [Windows.Forms.MessageBox]::Show("Please select a valid source folder.") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($dst)) {
        [Windows.Forms.MessageBox]::Show("Please select a destination folder.") | Out-Null
        return
    }
    if ($src.TrimEnd('\') -ieq $dst.TrimEnd('\')) {
        [Windows.Forms.MessageBox]::Show("Source and destination cannot be the same.") | Out-Null
        return
    }
    if ($dst.StartsWith($src.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) {
        [Windows.Forms.MessageBox]::Show("Destination cannot be inside the source folder.") | Out-Null
        return
    }

    $answer = [Windows.Forms.MessageBox]::Show(
        "Start copying?`n`nFrom: $src`nTo: $dst",
        "Confirm Transfer",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -ne "Yes") { return }

    try {
        New-Item -ItemType Directory -Path $dst -Force -ErrorAction Stop | Out-Null
    } catch {
        [Windows.Forms.MessageBox]::Show("Cannot create destination folder:`n$($_.Exception.Message)") | Out-Null
        return
    }

    $start.Enabled = $false
    $cancel.Enabled = $true
    $status.Text = "Copying... Please wait."
    $progress.MarqueeAnimationSpeed = 30

    # One hidden robocopy process, no loops. Low thread count is kinder to USB drives.
    $roboArgs = "$(Quote-Path $src) $(Quote-Path $dst) /E /MT:8 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP"
    $script:proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $roboArgs -WindowStyle Hidden -PassThru
    $null = $script:proc.Handle   # keeps the exit code available

    $script:timer = New-Object Windows.Forms.Timer
    $script:timer.Interval = 500
    $script:timer.Add_Tick({
        if ($script:proc -and $script:proc.HasExited) {
            $script:timer.Stop()
            $code = $script:proc.ExitCode

            $progress.MarqueeAnimationSpeed = 0
            $start.Enabled = $true
            $cancel.Enabled = $false

            if ($code -lt 8) {
                $status.Text = "Transfer completed successfully."
                [Windows.Forms.MessageBox]::Show("Transfer completed!") | Out-Null
            } else {
                $status.Text = "Transfer error. Code: $code"
                [Windows.Forms.MessageBox]::Show("Transfer failed or had errors. Code: $code") | Out-Null
            }
        }
    })
    $script:timer.Start()
})

$cancel.Add_Click({
    Stop-Transfer
    $progress.MarqueeAnimationSpeed = 0
    $start.Enabled = $true
    $cancel.Enabled = $false
    $status.Text = "Transfer cancelled."
})

# Closing the window must not leave robocopy running in the background
$form.Add_FormClosing({
    if ($script:proc -and -not $script:proc.HasExited) {
        $r = [Windows.Forms.MessageBox]::Show("A transfer is running. Stop it and exit?","Exit",
            [Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -ne "Yes") { $_.Cancel = $true; return }
        Stop-Transfer
    }
})

$send.Add_CheckedChanged({
    if ($send.Checked) {
        $form.Text = "USB Transfer - SEND"
        $srcRow.Label.Text = "SOURCE FOLDER (on PC)"
        $dstRow.Label.Text = "DESTINATION FOLDER (on USB)"
    }
})
$receive.Add_CheckedChanged({
    if ($receive.Checked) {
        $form.Text = "USB Transfer - RECEIVE"
        $srcRow.Label.Text = "SOURCE FOLDER (on USB)"
        $dstRow.Label.Text = "DESTINATION FOLDER (on PC)"
    }
})

[void]$form.ShowDialog()
