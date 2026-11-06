# USB File Transfer

A small Windows GUI for copying a folder between a PC and a USB drive. It wraps `robocopy` in a simple PowerShell/WinForms window, so no installation is needed.

## Requirements

- Windows 7 or later (uses built-in `robocopy.exe`, PowerShell and .NET WinForms)
- No extra software or admin rights

## Files

| File | Purpose |
|------|---------|
| `run.bat` | Launcher. Starts `Transfer.ps1` with execution-policy bypass so it runs on double-click. |
| `Transfer.ps1` | The GUI and transfer logic. |

Keep both files in the same folder.

## Usage

1. Double-click `run.bat`.
2. Choose a mode:
   - **SEND (PC to USB)**: source is on the PC, destination is on the USB.
   - **RECEIVE (USB to PC)**: source is on the USB, destination is on the PC.
3. Click **Browse...** to pick the source folder and the destination folder (or type a path; the destination is created if it does not exist).
4. Click **START TRANSFER** and confirm.
5. Wait for the "Transfer completed!" message. Use **CANCEL** to stop a running transfer.

## How it works

Rules the tool follows:

- All subfolders are copied, including empty ones (`/E`).
- Files are only copied or updated; nothing is deleted from the destination (no `/MIR`).
- Existing identical files are skipped by `robocopy`'s default behavior.
- Failed files are retried once after 1 second (`/R:1 /W:1`).
- 8 copy threads are used (`/MT:8`), which is gentle on USB drives.

Validation before copying:

- The source must be an existing folder.
- A destination must be given.
- Source and destination cannot be the same folder.
- The destination cannot be inside the source folder.

Result codes: `robocopy` exit codes below 8 mean success (files copied, skipped or extra files found). Code 8 or higher means errors, and the code is shown in the status line.

## Notes and limitations

- SEND and RECEIVE only change the labels and window title; both run the same copy operation.
- The progress bar is an activity indicator, not a percentage.
- Cancelling stops `robocopy` immediately; files already copied stay in the destination.
- Closing the window during a transfer asks for confirmation and stops the copy.
- Windows may show a SmartScreen warning for downloaded scripts; choose **More info > Run anyway** if you trust the source.
