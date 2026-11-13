# Lead King Phone Broadcast - implementation checkpoint

**Repository:** ravaunrichards/Lead-King-Phone-Broadcast  
**Working branch:** implementation/safe-setup-and-audit-tools  
**Base branch:** main  
**Scope:** safe repository-side implementation; original binaries and sample files retained

## Implemented in this branch

- Added a private local workspace initializer with separate audio, recording, call-list, configuration, log and backup folders. It refuses to create runtime storage inside the repository and preserves existing folders/files.
- Added static PE/WAV inspection. It reads headers and metadata only; it does not execute EXEs or load DLLs.
- Added a call-list preflight/preparation tool. It recognizes the documented 12-column and 15-column headers, handles the bundled sample's surplus trailing tab, maps the 12-column form to the 15-column schema, validates ten-digit numbers, excludes invalid/duplicate values, requires both explicit consent and suppression lists before generating output, and treats prior OptOut outcomes as suppression. Existing files and input data are never overwritten.
- Added synthetic call-list tests covering approved, suppressed, no-consent, prior-OptOut and duplicate rows, plus unchanged-input and 15-column assertions.
- Added a Windows GitHub Actions workflow to parse all PowerShell scripts, run synthetic tests, test workspace WhatIf behavior, and inspect assets without launching the legacy applications.
- Added a new README, SIP/SMTP configuration reference, credential-free .env.example and .gitignore protections.
- Original vendor ReadMe.txt, sample data, audio, executables, SDK files and icon are preserved. All changes are on a separate feature branch.

## Confirmed repository facts

- The repository is public and its default branch is main.
- The inventory contains BroadcastLite.exe, Setup.exe, 1_VOIP_Settings.txt, 2_Call_List.txt, two sample WAV files, CallListFormat.avi, MicroSIP-3.20.5.exe, AnyDesk.exe, VoIPSDK.dll, VoIPSDK_x64, VoIPSDK_x86, audacity-win-2.0.6.exe, king-icon.ico, ReadMe.txt and EULA.pdf.
- BroadcastLite.exe is a 586,752-byte PE32 / x86 Windows GUI executable. Static strings identify .NET Framework 4.5 metadata, Ozeki.VoIP.SDK references, SIP credential/registration fields, SMTP controls, scheduling, message playback/recording, DTMF/transfer/opt-out and product-licence workflow strings.
- Setup.exe is a 589,312-byte PE32 / x86 Windows GUI executable. Static strings describe it as a Lead King Phone Broadcast downloader/installer and show .NET Framework 4.0 Client profile metadata. It was not executed.
- The root VoIPSDK.dll is one byte and does not contain a PE header. It is not a usable Windows DLL.
- SDK folder names distinguish x86 and x64. LAME and vcomp100 helper DLLs have matching PE machine types. The Ozeki managed/native payloads were not available as complete bytes through the connected repository reader, so their machine type, signatures, assembly identity, version and dependencies are still unverified. The bridge EXE is x86 in both folder trees.
- The 2_Call_List.txt header has 12 columns. Its data rows contain one surplus trailing empty field. ReadMe.txt documents 15 columns, adding Undefined1, Undefined2 and Undefined3. Actual BroadcastLite import behavior is still unverified.
- Both sample WAVs have consistent RIFF sizes and PCM mono 8,000 Hz audio, but 16 bits per sample, not the 32 bits claimed in ReadMe.txt. Durations are approximately 15.025 seconds and 2.656 seconds.
- 1_VOIP_Settings.txt contains “Unlicensed 5 Call Trial Version”, placeholder “Unlicensed” fields, a sample date and example paths, not usable SIP-provider credentials.
- 2_Call_List.txt contains TEST CO rows and is sample data, not production customer records.

## Not completed / blocked

- No source project, solution, project files or editable BroadcastLite source was found.
- Licence behavior has not been changed. Vendor authorization is noted, but the source project or a verifiable vendor build path is not in the repository. No binary patching or licence circumvention has been performed.
- No current installer has been created. Setup.exe's downloader behavior, remote endpoint, payload and licensing conditions have not been validated.
- SIP registration, test calls, call transfer, DTMF, voicemail recording, SMTP delivery, scheduling, retries or the legacy application's import behavior have not been tested.
- EULA.pdf has not been reviewed; its licensing and redistribution terms must be verified before redistributing modified binaries or SDK components.
- No production SIP or SMTP credentials, caller ID, consent evidence or customer list have been supplied.
- The .env.example file documents field names only. BroadcastLite has not been demonstrated to consume it.

## Test status

- Completed statically: repository tree inventory; PE header and embedded-string inspection for primary executables; RIFF/WAV metadata and chunk-boundary inspection; call-list header and row-width inspection; committed-file SHA and branch checks.
- Automated validation is configured on a Windows GitHub Actions runner. Its first run was observed in progress at commit 768834b0a6c868db21b70b06bacedbb5350f5dd7. The final workflow conclusion must be checked before marking script tests as passed.
- Local container does not have PowerShell installed, so the PowerShell scripts have not been locally executed or parsed here.
- Not tested: live telephony, email delivery, application GUI, installation, runtime SDK loading, call flow, recordings, backup/restore and licence behavior.

## Production safety rules

- Keep runtime state outside the Git repository.
- Never store real SIP/SMTP secrets, customer data, consent evidence, recordings or logs in Git.
- Use verified permission-based recipient sources and maintain a current suppression file.
- Test only with controlled, authorized endpoints. Never call the sample TEST CO records.
- Preserve opt-outs across every future import, retry and campaign.
- Do not enable outbound broadcasting until the app, carrier, import format, call flow and compliance controls are verified.

## Next technical dependency

Provide the original editable BroadcastLite source project and vendor build instructions, or a vendor-signed supported build that includes the requested changes. Also provide the full Ozeki SDK package/version/license documentation and a real provider test account through a protected method before any SIP/SMTP verification.
