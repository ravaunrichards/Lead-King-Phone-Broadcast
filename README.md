# Lead King Phone Broadcast

This repository is the independent home of the legacy Lead King Phone Broadcast / BroadcastLite desktop application.

## Safety-first implementation status

Implementation work is being developed on the branch **implementation/safe-setup-and-audit-tools**. The original files on **main** are preserved. This work does not claim to rebuild the proprietary application or to activate a paid licence.

The repository currently contains compiled Windows executables and vendor SDK binaries, but no application source project or build solution. The desktop executable is a 32-bit .NET Framework application and contains references to Ozeki VoIP SDK and a product licence workflow. The root-level VoIPSDK.dll is only 1 byte and is not a valid DLL.

## Local workspace

Run PowerShell from a trusted Windows machine:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Initialize-BroadcastLiteWorkspace.ps1

By default, private runtime data is created under the current user's LOCALAPPDATA directory. Use -Root to choose another private local location. The script refuses to create runtime folders inside the Git repository so customer records and recordings do not accidentally become Git content.

The workspace contains separate locations for:
- Introduction messages and pre-introduction messages
- Pre-voicemail prompts and voicemail instructions
- Test audio and call announcements
- Caller-recorded messages, full call recordings, archives and failed recordings
- Call-list imports, examples, processed files and exports
- Configuration, logs and backups

Existing repository files are not moved or overwritten.

## Static asset inspection

Run:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Inspect-BroadcastLiteAssets.ps1

This checks PE headers and WAV metadata without executing the EXEs or loading DLLs. It is not a runtime or vendor SDK compatibility test.

## Call-list audit and preparation

Audit a tab-delimited call list without producing an output file:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Prepare-CallList.ps1 -InputPath .\2_Call_List.txt

Prepare a new 15-column file only after creating explicit, controlled consent and do-not-call lists:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Prepare-CallList.ps1 -InputPath .\Call_Lists\Imports\recipients.tsv -ConsentListPath .\Configuration\consented-10-digit-numbers.txt -SuppressionListPath .\Configuration\do-not-call-10-digit-numbers.txt -OutputPath .\Call_Lists\Processed\prepared-recipients.tsv

Important:
- Both the consent list and suppression list are required to generate an output file.
- Each list contains one 10-digit phone number per line. Blank lines and lines beginning with # are ignored.
- The tool refuses to overwrite input or existing output files.
- Previously recorded OptOut rows are suppressed.
- Duplicate and invalid phone rows are excluded.
- The supplied TEST CO sample records are never treated as production records. The optional AllowSampleRows switch is only for explicitly controlled tests.
- This script only prepares a file. It does not make telephone calls, verify that consent evidence is genuine, or prove that BroadcastLite accepts the prepared 15-column file.

The legacy application documentation specifies ten-digit phone numbers. International number handling must be verified with the original vendor/application before use.

## Legacy application and dependencies

Do not assume the included Setup.exe is a current installer. Static inspection identifies it as a compiled downloader-style setup program. It has not been launched.

Do not replace the 1-byte root VoIPSDK.dll with a DLL from one of the architecture-specific folders until the expected assembly identity, version, architecture and vendor packaging instructions are confirmed. The similarly named architecture-specific SDK files have not yet been validated as a coherent, redistributable SDK package.

## Credentials and privacy

Never commit SIP passwords, SMTP passwords, customer lists, consent evidence, suppression lists, voice messages, complete call recordings, or runtime logs. Keep them in access-controlled local storage. Do not paste secrets into issues, pull requests, or source files.

The repository's configuration sample is a trial/example file, not a real provider account. No SIP provider, SMTP server, caller ID, or production credentials are configured by this project.

## Licensing and source-code limitation

The compiled BroadcastLite executable contains a licence activation/unlicensing workflow and an unlicensed five-call trial reference. This implementation does not patch, bypass or remove that workflow. The vendor has stated that it authorizes the work, but the editable source code and a verifiable vendor build process are not present in this repository. Obtain the original source project and dependencies or provide a vendor-signed, license-free build before modifying this behavior.

## Verification boundary

PowerShell helper scripts are designed for Windows PowerShell 5.1 or later. They must be run on a Windows test machine before production use. They do not register SIP, send email, alter application licensing, or start broadcasts. Use controlled destinations only and confirm all calling permissions, opt-out processing, caller identification, calling-hour, and recording-consent obligations before placing any calls.
