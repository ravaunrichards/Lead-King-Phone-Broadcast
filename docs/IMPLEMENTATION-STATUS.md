# Lead King Phone Broadcast - implementation checkpoint

**Repository:** ravaunrichards/Lead-King-Phone-Broadcast  
**Default branch:** main  
**Current work branch:** implementation/sdk-metadata-audit  
**Safety:** original BroadcastLite/Setup/SDK executables and sample assets have not been replaced, moved or deleted

## Merged into main

### PR #1 - safe repository setup and validation tooling
- Merged at commit e4b42fa947fb40ef70b7120e208a0f60a42e3627.
- Added private local workspace initializer; static binary/WAV inspector; call-list preparation; synthetic tests; README; SIP/SMTP templates; .gitignore; Windows CI.
- Windows Actions passed on main: https://github.com/ravaunrichards/Lead-King-Phone-Broadcast/actions/runs/43428464482.

### PR #2 - call-list and opt-out hardening
- Merged at commit c7790dc470f2bc08e686396cfe1bf9a88b662b24.
- Added tests for both 12-column and 15-column input, trailing tabs, empty padding columns, invalid/duplicate/no-consent/suppressed rows, sample TEST CO refusal, output overwrite protection, unchanged input hashes and order-independent OptOut suppression.
- A later duplicate OptOut now suppresses an earlier row for the same phone number.
- Windows CI passed before merge: https://github.com/ravaunrichards/Lead-King-Phone-Broadcast/actions/runs/43429447581. Main CI after merge: https://github.com/ravaunrichards/Lead-King-Phone-Broadcast/actions/runs/43429643664.

## Current SDK audit branch

Branch: implementation/sdk-metadata-audit  
Latest tested commit: a1b212d2a53f615a437fe3afc1520056c379270f  
Windows CI: passed - https://github.com/ravaunrichards/Lead-King-Phone-Broadcast/actions/runs/43430735159

Added on this branch:
- Extended static inspector for SHA-256, version metadata, Authenticode signer/status and .NET assembly identity/reference details.
- tools/Test-VoIPSDKPackage.ps1 compares the app's referenced VoIPSDK assembly identity to both managed wrapper DLLs and checks native x86/x64 PE machine types.
- Windows CI includes the identity/architecture check plus a 32-bit PowerShell metadata-inspection pass.
- docs/VOIP-SDK-LICENSING.md documents the separate third-party SDK entitlement and compatibility requirements.

### Confirmed static SDK results
- BroadcastLite.exe is a PE32/x86 .NET assembly with product assembly version 1.0.0.22.
- Its assembly manifest references VoIPSDK, version 10.1.1.457, culture neutral, public-key token 4812fb35129b8487.
- VoIPSDK_x86/VoIPSDK_32bit.dll reports the same managed assembly identity.
- VoIPSDK_x64/VoIPSDK_64bit.dll reports the same managed assembly identity.
- The x86 native library is PE machine type x86; the x64 native library is PE machine type x64.
- CLR-header inspection (run 43432188074) establishes BroadcastLite.exe CLR flags 0x00000003: IL-only, 32-bit required. Both managed wrappers have CLR flags 0x00000001: IL-only, AnyCPU-compatible. Therefore the 32-bit app must use the x86 native library; the x64 native library cannot be loaded in this process. The automated SDK package test now asserts this app/wrapper/native architecture pairing.
- The x64 wrapper metadata references other assemblies, including antlr.runtime, BouncyCastle.Crypto, AForge.Imaging and log4net. These dependencies must be resolved against the exact SDK distribution; do not assume the runtime files are present just because references appear in metadata.
- Reflection-only inspection did not yield the full x86 wrapper reference list, even under 32-bit PowerShell. Its identity and architecture checks passed, but the x86 reference chain remains incomplete.
- Authenticode status: BroadcastLite.exe, Setup.exe and Ozeki SDK binaries report NotSigned; Microsoft vcomp100 files report Valid and are signed by Microsoft. NotSigned is a trust/verification gap, not proof of tampering. The strong-name token confirms assembly identity but does not prove a commercial SDK licence.
- Root VoIPSDK.dll is a one-byte Git blob and is not a valid PE/managed DLL. It must not be replaced until packaging/runtime verification is complete.

## Confirmed legacy repository facts
- ReadMe.txt describes an old downloader installer Setup.exe; it was not run.
- 1_VOIP_Settings.txt contains sample/unlicensed placeholders and example paths, not real SIP credentials.
- 2_Call_List.txt contains a 12-column header and sample TEST CO contacts; it is not production data.
- The README claims 15 columns; the three extra fields are Undefined1, Undefined2 and Undefined3.
- Both bundled WAV files are valid RIFF PCM mono 8 kHz, 16-bit, not 32-bit as claimed in ReadMe.txt. Durations are approximately 15.025 seconds and 2.656 seconds.
- The app source and a build solution have not been found in this repository.

## Not yet completed / requires further work
- No editable BroadcastLite project/solution/source code. The Lead King product licence gate has not been modified because no auditable source/build path exists.
- Ozeki SDK is a separate third-party licensed component. Official Ozeki licensing guidance bases the standard license on simultaneous call capacity and SIP account count, allows copies of one licensed product without per-copy royalties, and requires separate activations for each developer workstation and an independent build server. Vendor authorization for Lead King is not a substitute for the Ozeki entitlement for this product/version/capacity. Review the original Ozeki receipt/package terms before redistribution or activation changes. Ozeki currently lists SDK v10.5.3; later releases require a newer framework baseline than this .NET Framework 4.5 app, so a version upgrade needs source-level migration.
- EULA.pdf has not been reviewed in a rendered PDF viewer; do not redistribute/modify vendor or third-party binaries until reviewed.
- SDK dependency resolution, CLR flags, loadability, native-library search paths and runtime compatibility remain unverified.
- Setup.exe downloader endpoint/payload/current installer behavior has not been verified.
- SIP registration, calls, transfer, DTMF, call outcomes, message recording and real call flow have not been tested.
- SMTP authentication and email delivery have not been tested.
- No real provider accounts, caller ID, production list, consent evidence or live SMTP settings have been supplied through secure configuration.
- No real broadcasts were placed; no customer data has been processed.
- No full runtime backup/restore test has been run.

## Safety rules retained
- Keep logs, customer lists, secrets and all recordings outside the Git repository.
- Never use TEST CO sample rows as production call targets.
- Keep consent and suppression lists current. Every OptOut suppresses that phone number regardless of duplicate-row order.
- Do not initiate campaigns until consent, calling-hour, caller-ID, opt-out and recording-notice requirements are verified.
- Never log SIP/SMTP passwords or SDK license keys.

## Next milestone
Obtain the original editable BroadcastLite source/build project and the exact licensed Ozeki SDK package/documentation for version 10.1.1.457. Then verify CLR flags and dependency loading in a controlled Windows VM before making any application binary or SDK placement changes. A real provider test account and SMTP test account must be supplied through secure credential storage before live service tests.
