# Ozeki VoIP SDK - third-party licensing and compatibility

## What the repository proves

Static .NET metadata inspection on a Windows runner confirms:

- BroadcastLite.exe references a managed assembly named VoIPSDK.
- The reference is version 10.1.1.457, culture neutral, public-key token 4812fb35129b8487.
- VoIPSDK_x86/VoIPSDK_32bit.dll and VoIPSDK_x64/VoIPSDK_64bit.dll report the same assembly name, version, culture and public-key token as the application reference.
- The x86 native SDK library is PE machine type x86; the x64 native SDK library is PE machine type x64.
- The root VoIPSDK.dll is only a two-byte invalid placeholder, not a managed assembly.
- Authenticode inspection reports the Ozeki managed/native SDK files as NotSigned. The vcomp100 redistributable DLLs are Authenticode-signed by Microsoft.

The CLR-header audit adds an important architecture finding:
- BroadcastLite.exe has CLR flags 0x00000003: IL-only and 32-bit required.
- Both managed SDK wrappers have CLR flags 0x00000001: IL-only and AnyCPU-compatible.
- Therefore, the process is 32-bit and must use the x86 native library. The x64 native library is not compatible with the BroadcastLite process architecture.
- The inspector and CI test now assert these execution models and the x86 pairing.

These are static metadata and file-header findings. They do not prove the binaries are licensed for this product, that native libraries load, or that the SDK can register with a provider.

## Lead King product licensing versus Ozeki SDK licensing

These are separate matters:

1. **Lead King / BroadcastLite product licence:** The owner/vendor has authorized changes to the product's own registration/licensing behavior. No executable patch has been made; the repository has no editable BroadcastLite source project or vendor build solution.
2. **Ozeki VoIP SDK licence:** The managed assembly is third-party software. The product owner's authorization for Lead King does not change Ozeki's terms.

Ozeki's current published licensing FAQ states that:
- A standard license is based on simultaneous-call capacity and the number of SIP accounts used.
- One standard license covers one product or service; that licensed product can be distributed in multiple copies without per-copy royalties.
- A single license can support multiple client installations; licensing is not calculated per end user.
- A license code can be activated on one developer workstation only. An independent build server requires its own license activation.
- Subsequent versions of the same application do not require a separate SDK product license, while a different application/service does.
- The 10,000-simultaneous-call package is the package whose FAQ entry says it includes full SDK source code.

The FAQ describes current standard licensing; the exact entitlement, permitted call capacity, SIP-account count, product identity and activation rights for the bundled 10.1.1.457 files still need to be confirmed against the original purchase receipt/license and version-specific terms.

The vendor's current download page lists Ozeki SDK v10.5.3 (updated 2026-10-22) with .NET 10 builds. Its history states that later .NET Framework builds moved to .NET Framework 4.8 at version 10.3.190. This application targets .NET Framework 4.5, so simply replacing the 10.1.1.457 DLLs with a newer release is not a safe upgrade. Source-level migration and compatibility testing would be required.

Official references:
- Licensing FAQ: https://www.voip-sip-sdk.com/p_7226-voip-sdk-licensing-faq.html
- SDK releases and current framework requirements: https://voip-sip-sdk.com/p_7021-download-ozeki-voip-sip-sdk.html
- Ozeki SDK product page: https://www.voip-sip-sdk.com/

Do not remove or patch Ozeki SDK licensing/activation. For a license-free end-user experience, the lawful route is to confirm the vendor holds the appropriate SDK license for this product and then implement the vendor-supported distribution/activation model in the source build.

## Required before enabling a production runtime

- Confirm the Ozeki license entitlement, permitted product/service, simultaneous-call capacity and developer/build-machine activations for this SDK version.
- Obtain the original SDK installer/package and its matching redistribution documentation.
- Confirm whether the x86 or x64 managed wrapper is appropriate for the actual application process and the intended native library. Both wrappers match the manifest identity, but their native dependencies differ.
- Resolve every non-framework assembly reference (the static audit found references including antlr.runtime, BouncyCastle.Crypto, AForge.Imaging and log4net in the x64 wrapper metadata) against the exact licensed SDK package.
- Confirm the expected placement/search path for VoIPSDK.dll, VoIPSDK_NativeLib_x86.dll, codec libraries and any bridge/helper executable.
- Test load/registration only in a controlled Windows environment with a valid SDK license and a real provider test account.

## Credential handling

Do not place Ozeki license codes, SIP passwords, SMTP passwords or provider activation codes in GitHub. Store them in a private credential vault or Windows Credential Manager and only make them available to the authorized build/runtime process.
