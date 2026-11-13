# Lead King Phone Broadcast - implementation checkpoint

**Repository:** ravaunrichards/Lead-King-Phone-Broadcast  
**Working branch:** implementation/safe-setup-and-audit-tools  
**Base branch:** main  
**Scope:** safe repository-side implementation; original binaries and sample files retained

## Implemented in this branch

- Added a private local workspace initializer with distinct audio, recording, call-list, configuration, log and backup folders.
- Added static PE/WAV inspection. It reads file headers and metadata only; it does not execute EXEs or load DLLs.
- Added a call-list preflight/preparation tool. It recognizes the documented 12-column and 15-column headers, handles the bundled sample's surplus trailing tab, maps the 12-column form to the documented 15-column output schema, validates ten-digit phone values, suppresses duplicates, applies a mandatory consent list and do-not-call list for output generation, and treats prior OptOut outcomes as suppression.
- Added a new README while retaining the vendor's original ReadMe.txt unchanged.
- All work is confined to this feature branch. No original file is deleted, moved, renamed, or overwritten.

## Confirmed repository facts

- The repository is public and its default branch is main.
- The repository inventory contains BroadcastLite.exe, Setup.exe, 1_VOIP_Settings.txt, 2_Call_List.txt, two sample WAV files, CallListFormat.avi, MicroSIP-3.20.5.exe, AnyDesk.exe, VoIPSDK.dll, VoIPSDK_x64, VoIPSDK_x86, audacity-win-2.0.6.exe, king-icon.ico, ReadMe.txt and EULA.pdf.
- BroadcastLite.exe is a 586,752-byte PE32 / x86 Windows GUI executable. Static string inspection identifies .NET Framework 4.5 metadata, Ozeki.VoIP.SDK references, SIP credential/registration fields, SMTP controls, scheduling controls, message playback/recording controls, DTMF/transfer/opt-out controls and product-license workflow strings.
- Setup.exe is a 589,312-byte PE32 / x86 Windows GUI executable. Static strings describe it as a Lead King Phone Broadcast downloader/installer. It targets a .NET Framework 4.0 Client profile according to embedded metadata strings. It was not executed.
- The root VoIPSDK.dll is one byte and does not contain a PE header. It is not a usable Windows DLL.
- Architecture-specific SDK folders contain x86 and x64 names, but the two large Ozeki managed/native DLLs in each folder could not be fully downloaded for signature, version, dependency and architecture verification. Smaller LAME and vcomp100 support DLLs have matching PE machine types: x86 in the x86 folder and x64 in the x64 folder. The bridge executable is x86 in both folder trees.
- The call-list header in 2_Call_List.txt has 12 columns. The file's data rows contain a surplus trailing empty field. ReadMe.txt documents 15 columns, adding Undefined1, Undefined2 and Undefined3. The actual application's import behavior remains unverified.
- Both supplied WAVs have consistent RIFF sizes and PCM mono 8,000 Hz audio, but 16 bits per sample, not the 32 bits claimed in ReadMe.txt. Their durations are approximately 15.025 seconds and 2.656 seconds.
- 1_VOIP_Settings.txt contains the text "Unlicensed 5 Call Trial Version", placeholder "Unlicensed" fields, a sample date, an example Windows directory and an old server path. It does not contain usable SIP provider credentials.
- 2_Call_List.txt contains TEST CO rows and is sample data, not a production contact list.

## Not completed / blocked

- No source project, solution, project files or editable application source has been found in the repository.
- The product licensing workflow cannot be safely or verifiably changed in the compiled executable alone. Vendor authorization is noted, but a source project or vendor-supported build/release path is still required. No binary patching or licence circumvention has been performed.
- No current installer has been created. The setup executable's downloader behavior, remote endpoint, payload and licensing conditions have not been validated.
- SIP registration, real test calls, call transfer, DTMF, voicemail recording, SMTP delivery, scheduling, retry logic, or actual BroadcastLite import behavior have not been tested.
- The EULA remains to be reviewed in its rendered form. Do not infer redistribution or modification rights from the user's authorization alone.
- No production provider credentials, caller ID, email settings, consent evidence or customer list have been supplied.

## Test status

- Completed: repository tree inventory; static PE header inspection for primary EXEs and selected support DLLs; static inspection of application strings; RIFF/WAV metadata and chunk-boundary inspection; call-list header and row-width inspection.
- Pending on Windows: run PowerShell parser/static validation, execute the workspace initializer with WhatIf first, inspect WAVs using the actual target application, and run call-list tests using synthetic records and consent/suppression files.
- Not tested: all live telephony, email, application installation, GUI, call-flow, recording, backup/restore and licensing workflows.

## Production safety rules

- Keep runtime state outside the Git repository.
- Never store real SIP/SMTP secrets, customer data, recordings, call logs or consent evidence in Git.
- Use written permission-based recipient sources and maintain a current suppression file.
- Test only with controlled, authorized destinations. Do not use the sample TEST CO list for calls.
- Preserve opt-outs across all future imports and retries.
- Do not enable automated broadcasting until the application, provider, call flow, opt-out behavior and local compliance controls are verified.

## Next technical dependency

Provide the original editable BroadcastLite source project and vendor build instructions, or a vendor-signed supported build that includes the required modifications. Also provide the Ozeki SDK package/version/license documentation and a valid provider test account through a protected method before any real SIP or SMTP verification.
