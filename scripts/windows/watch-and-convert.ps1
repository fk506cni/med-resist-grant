<#
.SYNOPSIS
    Watches the script's folder for new .docx files and auto-converts them to PDF using Microsoft Word.

.DESCRIPTION
    This script runs as a persistent watcher. When a new .docx file appears in the
    same folder as this script, it waits for the file to become accessible (handling
    Google Drive sync locks), converts it to PDF via Word COM automation, and moves
    the original .docx into a "processed" subfolder.

    Designed for use with Google Drive sync folders where .docx files are delivered
    automatically and need to be converted to PDF without manual intervention.

    Project: med-resist-grant (薬剤耐性研究 科研費申請書類作成システム)

.NOTES
    Requires: Microsoft Word installed on the machine.

    === How to Run ===

    Method 1: Right-click and "Run with PowerShell"
      - Right-click this file in Explorer -> "Run with PowerShell"
      - Note: The window may close on errors. Method 2 is recommended.

    Method 2: From a PowerShell terminal (RECOMMENDED)
      1. Open PowerShell (or Windows Terminal)
      2. Navigate to the folder containing this script:
             cd "C:\path\to\your\folder"
      3. If you've never run PowerShell scripts before, allow execution:
             Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
      4. Run the script:
             .\watch-and-convert.ps1
      5. The script will now watch for .docx files. Press Ctrl+C to stop.

    Method 3: Double-click watch-and-convert.bat
      - The companion .bat file launches this script automatically.

    === Folder Structure ===

    Place this script in the Google Drive sync folder:

        med-resist-grant/               <- Google Drive sync folder
        ├── watch-and-convert.ps1       <- this script
        ├── watch-and-convert.bat       <- launcher
        ├── youshiki1_5_filled.docx     <- synced from Linux
        ├── products/                   <- PDF output here (auto-created, syncs back)
        │   └── youshiki1_5_filled.pdf
        ├── processed/                  <- converted .docx moved here (auto-created)
        └── error/                      <- failed .docx moved here (auto-created)

    === Configuration ===

    Edit the variables in the "Configuration" region below to adjust:
      - $PollIntervalSec    : How often to check for new files (default: 5 seconds)
#>

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
#region Configuration
# ============================================================================

$PollIntervalSec = 5     # Polling interval in seconds

#endregion

# ============================================================================
#region Helper Functions
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO'  { 'Cyan' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'OK'    { 'Green' }
    }
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[$Level] " -NoNewline -ForegroundColor $color
    Write-Host $Message
}

function Test-FileReady {
    <#
    .SYNOPSIS
        Tests whether a file can be opened exclusively (i.e., not locked by another process).
    #>
    param([string]$Path)
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None
        )
        $stream.Close()
        $stream.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Convert-DocxToPdf {
    <#
    .SYNOPSIS
        Converts a .docx file to PDF by spawning a VBScript subprocess.
        VBScript has proper COM message pumping, avoiding the deadlock
        that occurs when PowerShell calls Word COM PDF export directly.
    #>
    param(
        [string]$DocxPath,
        [string]$OutputDir
    )

    $fileName = Split-Path $DocxPath -Leaf
    $pdfName  = [System.IO.Path]::ChangeExtension($fileName, '.pdf')
    $pdfPath  = Join-Path $OutputDir $pdfName

    # Work in %TEMP% to avoid Google Drive sync locks (unique dir per file)
    $uniqueId = [System.IO.Path]::GetRandomFileName().Replace('.','')
    $tempDir  = Join-Path $env:TEMP "docx2pdf_$uniqueId"
    $tempDocx = Join-Path $tempDir $fileName
    $tempPdf  = Join-Path $tempDir $pdfName
    $tempVbs  = Join-Path $tempDir 'convert.vbs'

    try {
        # Copy source to temp (outside Google Drive)
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Copy-Item -Path $DocxPath -Destination $tempDocx -Force
        Unblock-File -Path $tempDocx
        $tempSize = (Get-Item $tempDocx).Length
        Write-Log "Temp: $tempDocx ($tempSize bytes)" 'INFO'

        # Generate VBScript for Word COM PDF export
        # VBScript runs in its own STA with proper message pumping.
        $vbs = @"
On Error Resume Next
Dim wdApp, doc
Set wdApp = CreateObject("Word.Application")
wdApp.Visible = False
wdApp.DisplayAlerts = 0

Set doc = wdApp.Documents.Open("$($tempDocx.Replace('\','\\'))", False, True, False)
If Err.Number <> 0 Then
    WScript.StdErr.WriteLine "OPEN_ERROR: " & Err.Description
    wdApp.Quit 0
    WScript.Quit 1
End If

doc.SaveAs2 "$($tempPdf.Replace('\','\\'))", 17
If Err.Number <> 0 Then
    WScript.StdErr.WriteLine "SAVEAS_ERROR: " & Err.Description
    doc.Close 0
    wdApp.Quit 0
    WScript.Quit 2
End If

doc.Close 0
wdApp.Quit 0
WScript.Quit 0
"@
        # Write VBScript (use ASCII encoding for cscript compatibility)
        [System.IO.File]::WriteAllText($tempVbs, $vbs, [System.Text.Encoding]::Default)

        # Run VBScript via cscript.exe (has proper COM message pump)
        Write-Log "Converting via cscript (VBScript)..." 'INFO'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $proc = Start-Process -FilePath 'cscript.exe' `
            -ArgumentList '//Nologo', $tempVbs `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardError (Join-Path $tempDir 'stderr.txt')

        $sw.Stop()
        $exitCode = $proc.ExitCode
        Write-Log "[DEBUG] cscript exited with code $exitCode in $($sw.ElapsedMilliseconds)ms" 'INFO'

        # Check stderr for errors
        $stderrFile = Join-Path $tempDir 'stderr.txt'
        if ((Test-Path $stderrFile) -and (Get-Item $stderrFile).Length -gt 0) {
            $stderrContent = Get-Content $stderrFile -Raw
            Write-Log "[DEBUG] stderr: $stderrContent" 'WARN'
        }

        if ($exitCode -ne 0) {
            Write-Log "VBScript conversion failed (exit code: $exitCode)" 'ERROR'
            return $null
        }

        # Verify temp PDF exists
        if (-not (Test-Path $tempPdf)) {
            Write-Log "PDF not created at: $tempPdf" 'ERROR'
            return $null
        }
        $pdfSize = (Get-Item $tempPdf).Length
        Write-Log "[DEBUG] PDF size: $pdfSize bytes" 'INFO'

        # Copy final PDF to products/
        Copy-Item -Path $tempPdf -Destination $pdfPath -Force
        Write-Log "PDF created: $pdfName" 'OK'
        return $pdfPath

    } catch {
        Write-Log "Conversion failed: $($_.Exception.Message)" 'ERROR'
        Write-Log "[DEBUG] $($_.ScriptStackTrace)" 'ERROR'
        return $null

    } finally {
        # Clean up temp directory
        if (Test-Path $tempDir) {
            try { Remove-Item -Path $tempDir -Recurse -Force } catch { }
        }
    }
}

#endregion

# ============================================================================
#region Main
# ============================================================================

# Resolve the watch directory (= directory where this script lives)
$WatchDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProductsDir  = Join-Path $WatchDir 'products'
$ProcessedDir = Join-Path $WatchDir 'processed'
$ErrorDir     = Join-Path $WatchDir 'error'

# Ensure products directory exists
if (-not (Test-Path $ProductsDir)) {
    New-Item -ItemType Directory -Path $ProductsDir -Force | Out-Null
}

# Banner
Write-Host ''
Write-Host '========================================================' -ForegroundColor White
Write-Host '  DOCX -> PDF  Auto-Converter (Folder Watcher)' -ForegroundColor White
Write-Host '  Project: med-resist-grant' -ForegroundColor DarkGray
Write-Host '========================================================' -ForegroundColor White
Write-Host ''
Write-Log "Watch folder : $WatchDir" 'INFO'
Write-Log "PDF output   : $ProductsDir" 'INFO'
Write-Log "Processed to : $ProcessedDir" 'INFO'
Write-Log "Error to     : $ErrorDir" 'INFO'
Write-Log "Poll interval: ${PollIntervalSec}s" 'INFO'
Write-Host ''
Write-Log "Watching for .docx files... Press Ctrl+C to stop." 'INFO'
Write-Host ''

# Helper: ensure directory exists and move file there (with collision handling)
function Move-ToFolder {
    param(
        [string]$FilePath,
        [string]$DestDir,
        [string]$Label
    )
    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        Write-Log "Created folder: $Label/" 'INFO'
    }
    $fileName = Split-Path $FilePath -Leaf
    $destPath = Join-Path $DestDir $fileName
    if (Test-Path $destPath) {
        $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $newName   = "${baseName}_${timestamp}.docx"
        $destPath  = Join-Path $DestDir $newName
    }
    Move-Item -Path $FilePath -Destination $destPath -Force
    return (Split-Path $destPath -Leaf)
}

# --- Stateless polling loop ---
# Every cycle, scan the watch folder for ALL .docx files.
#   - Locked files  -> skip (will be retried next cycle automatically)
#   - Convert OK    -> move to processed/
#   - Convert FAIL  -> move to error/
try {
    while ($true) {
        $currentFiles = Get-ChildItem -Path $WatchDir -Filter '*.docx' -File -ErrorAction SilentlyContinue

        foreach ($file in $currentFiles) {
            # Skip temporary Word files (~$*.docx)
            if ($file.Name -like '~`$*') {
                continue
            }

            $filePath = $file.FullName

            # Check file lock (single attempt -- no blocking wait)
            if (-not (Test-FileReady -Path $filePath)) {
                Write-Log "Locked (sync in progress?): $($file.Name) -- will retry next cycle" 'WARN'
                continue
            }

            # File is ready -- process it
            Write-Host ''
            Write-Host '--------------------------------------------------------' -ForegroundColor DarkCyan
            Write-Log "Processing: $($file.Name)" 'INFO'

            $pdfResult = Convert-DocxToPdf -DocxPath $filePath -OutputDir $ProductsDir

            if ($pdfResult) {
                $movedName = Move-ToFolder -FilePath $filePath -DestDir $ProcessedDir -Label 'processed'
                Write-Log "Moved docx to: processed/$movedName" 'OK'
            } else {
                $movedName = Move-ToFolder -FilePath $filePath -DestDir $ErrorDir -Label 'error'
                Write-Log "Moved failed docx to: error/$movedName" 'ERROR'
            }

            Write-Host '--------------------------------------------------------' -ForegroundColor DarkCyan
            Write-Host ''
        }

        Start-Sleep -Seconds $PollIntervalSec
    }
} finally {
    Write-Log "Watcher stopped." 'WARN'
}

#endregion
