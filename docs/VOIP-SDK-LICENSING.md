# Ozeki VoIP SDK - third-party licensing and compatibility

## What the repository proves

Static .NET metadata inspection on a Windows runner confirms:

- BroadcastLite.exe references a managed assembly named VoIPSDK.
- The reference is version 10.1.1.457, culture neutral, public-key token 4812fb35129b8487.
- VoIPSDK_x86/VoIPSDK_32bit.dll and VoIPSDK_x64/VoIPSDK_64bit.dll report the same assembly name, version, culture and public-key token as the application reference.
- The x86 native SDK library is PE machine type x86; the x64 native SDK library is PE machine type x64.
- The root VoIPSDK.dll is only a two-byte invalid placeholder, not a managed assembly.
- Authenticode inspection reports the Ozeki managed/native SDK files as NotSigned. The vcomp100 redistributable DLLs are Authenticode-signed by Microsoft.

These are static metadata and file-header findings. They do not prove the binaries are licensed for this product, that native libraries load, or that the SDK can register with a provider.

## Lead King product licensing versus Ozeki SDK licensing

These are separate matters:

1. **Lead King / BroadcastLite product licence:** The owner/vendor has authorized changes to the product's own registration/licensing behavior. No executable patch has been made; the repository has no editable BroadcastLite source project or vendor build solution.
2. **Ozeki VoIP SDK licence:** The managed assembly is third-party software. The product owner's authorization for Lead King does not change Ozeki's terms.

Ozeki's published licensing FAQ states that SDK licensing is based on simultaneous-call capacity and SIP accounts. It describes a purchased standard license as applying to one product or service, with copies of that one product distributable without per-copy royalties, and it states that separate development workstation/build-server activation may be required. The precise terms applicable to the bundled 10.1.1.457 package must be checked against the license/receipt that accompanied that version.

Official references:
- https://www.voip-sip-sdk.com/p_7226-voip-sdk-licensing-faq.html
- https://www.voip-sip-sdk.com/

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
