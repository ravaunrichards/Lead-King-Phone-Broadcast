# Lead King Phone Broadcast

This repository is the independent home of the legacy Lead King Phone Broadcast / BroadcastLite desktop application.

## Safety-first implementation status

Repository-side safety tooling and call-list fixes have been merged into **main**. Additional SDK metadata auditing is being developed on the separate branch **implementation/sdk-metadata-audit**. The original BroadcastLite, Setup and SDK binaries have not been replaced or patched.

The repository contains compiled Windows executables and vendor SDK binaries, but no editable application source project or build solution. BroadcastLite.exe is a 32-bit .NET Framework application. Static assembly inspection confirms that it references Ozeki VoIP SDK assembly VoIPSDK version 10.1.1.457, public-key token 4812fb35129b8487. Both the x86 and x64 folder managed wrappers report the same assembly identity. The root-level VoIPSDK.dll is a one-byte Git blob and is not a valid DLL.

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

This reads PE headers, file/product versions, SHA-256 hashes, Authenticode status, managed assembly identity and references, and WAV metadata. Managed assemblies are inspected with reflection-only metadata APIs; no application entry point is started. It does not prove third-party SDK licensing, native DLL loading, runtime dependency resolution, SIP registration or call quality.

## Ozeki SDK audit

Run the read-only package identity check:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\\tools\\Test-VoIPSDKPackage.ps1

Windows CI confirms that BroadcastLite.exe, VoIPSDK_x86/VoIPSDK_32bit.dll and VoIPSDK_x64/VoIPSDK_64bit.dll share the VoIPSDK assembly name, version 10.1.1.457 and public-key token 4812fb35129b8487. The native x86 and x64 DLL headers match their named architectures. SDK metadata also identifies third-party assembly references that must be resolved against the exact licensed SDK distribution. See docs/VOIP-SDK-LICENSING.md. The currently published Ozeki SDK is newer than the bundled 10.1.1.457 package; do not replace it without a source-level migration because later releases have different .NET Framework requirements.

CLR-header inspection confirms BroadcastLite.exe is IL-only but 32-bit-required (flags 0x00000003). Both managed VoIPSDK wrappers are IL-only AnyCPU-compatible (flags 0x00000001). The application therefore must use the x86 native SDK library; the x64 native library cannot be loaded into its 32-bit process. This is a static architecture pairing, not a runtime load test. Authenticode reports the Ozeki binaries as NotSigned. A strong-name public-key token is an assembly identity, not proof of the vendor's commercial licence.

Do not copy an SDK DLL into the root or alter the root placeholder until the vendor package layout, dependencies, licensing and runtime resolution have been verified.

## Call-list audit and preparation

Audit a tab-delimited call list without producing an output file:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Prepare-CallList.ps1 -InputPath .\2_Call_List.txt

Prepare a new 15-column file only after creating explicit, controlled consent and do-not-call lists:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Prepare-CallList.ps1 -InputPath .\Call_Lists\Imports\recipients.tsv -ConsentListPath .\Configuration\consented-10-digit-numbers.txt -SuppressionListPath .\Configuration\do-not-call-10-digit-numbers.txt -OutputPath .\Call_Lists\Processed\prepared-recipients.tsv

Important:
- Both the consent list and suppression list are required to generate an output file.
- Each list contains one 10-digit phone number per line. Blank lines and lines beginning with # are ignored.
- The tool refuses to overwrite input or existing output files.
- Any OptOut row suppresses the phone number, including an OptOut on a later duplicate row.
- Duplicate and invalid phone rows are excluded.
- The supplied TEST CO sample records are never treated as production records. The optional AllowSampleRows switch is only for explicitly controlled tests.
- This script only prepares a file. It does not make telephone calls, verify that consent evidence is genuine, or prove that BroadcastLite accepts the prepared 15-column file.

The legacy application documentation specifies ten-digit phone numbers. International number handling must be verified with the original vendor/application before use.

## SIP and SMTP configuration

See docs/CONFIGURATION-REFERENCE.md and .env.example for the required fields and credential-handling rules. The example file contains only replacement text; it is not real provider configuration and the legacy executable has not been shown to read environment variables or .env files. Do not place actual passwords in GitHub.

## Automated safe validation

A Windows GitHub Actions workflow is included at .github/workflows/validate.yml. It parses the PowerShell scripts, runs synthetic 12-column and 15-column call-list tests, exercises the workspace initializer in WhatIf mode, performs read-only asset inspection, verifies Ozeki assembly identity/native architecture, and inspects metadata in 32-bit PowerShell. It never launches BroadcastLite, Setup.exe, MicroSIP or AnyDesk and does not place calls. See the latest SDK audit run: https://github.com/ravaunrichards/Lead-King-Phone-Broadcast/actions/runs/43430735159.

Run the same synthetic test locally:

    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\tools\Test-CallList.ps1

## Legacy application and dependencies

Do not assume the included Setup.exe is a current installer. Static inspection identifies it as a compiled downloader-style setup program. It has not been launched.

Do not replace the 1-byte root VoIPSDK.dll with a DLL from one of the architecture-specific folders. The application manifest and both folder wrappers now match at the managed assembly identity level (VoIPSDK, version 10.1.1.457, token 4812fb35129b8487), and CI verified x86/x64 native PE headers. However, the x86 wrapper's full managed reference list could not be recovered by reflection-only inspection, and runtime dependency resolution/loading remains untested. Some non-framework references are visible in the x64 wrapper metadata, including antlr.runtime, BouncyCastle.Crypto, AForge.Imaging and log4net; the exact licensed SDK package must be used to establish which dependencies are required and redistributable.

## Credentials and privacy

Never commit SIP passwords, SMTP passwords, customer lists, consent evidence, suppression lists, voice messages, complete call recordings, or runtime logs. Keep them in access-controlled local storage. Do not paste secrets into issues, pull requests, or source files. The .gitignore file protects common local-secret and operational-data paths, but it is not a substitute for reviewing every file before commit.

The repository's configuration sample is a trial/example file, not a real provider account. No SIP provider, SMTP server, caller ID, or production credentials are configured by this project.

## Licensing and source-code limitation

The compiled BroadcastLite executable contains a Lead King product licence activation/unlicensing workflow and an unlicensed five-call trial reference. The owner/vendor has authorized changes to this product's own licensing behavior, but the editable source code and a verifiable build solution are not present in this repository, so the product licence gate has not been changed. Ozeki SDK licensing is separate: the SDK is third-party software and requires the entitlement applicable to version 10.1.1.457, this product and its call/account capacity. Do not remove or patch Ozeki SDK licensing. See docs/VOIP-SDK-LICENSING.md.

## Verification boundary

PowerShell helper scripts are designed for Windows PowerShell 5.1 or later. They must be run on a Windows test machine before production use. They do not register SIP, send email, alter application licensing, or start broadcasts. Use controlled destinations only and confirm all calling permissions, opt-out processing, caller identification, calling-hour, and recording-consent obligations before placing any calls.
