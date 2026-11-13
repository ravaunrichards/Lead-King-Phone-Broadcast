# Configuration reference

## Important compatibility notice

The .env.example file is a credential-free reference template only. The existing BroadcastLite executable has not been shown to read environment variables, JSON, or this template. Do not expect changes to this file to configure the legacy application. Real SIP and SMTP settings must be entered through the actual application's supported configuration controls or implemented in a source-controlled successor build after the original source and SDK are obtained.

## SIP fields to confirm with the chosen carrier

| Field | Required information |
|---|---|
| Provider name | Carrier/product name |
| SIP server | Exact registrar/domain supplied by the carrier |
| Port | Carrier-supported SIP port |
| Username | SIP account username |
| Authentication ID | SIP digest-authentication ID, if different |
| Password | Secret; never commit or log |
| Outbound caller ID | Number/name the carrier authorizes for this account |
| Transport | UDP, TCP or TLS only as supported by provider and SDK |
| Registration expiry | Provider-supported registration interval |
| Codec preference | Intersection of provider, SDK and remote-endpoint support |
| Proxy | Only where required and supported; the legacy README claims proxy service is unsupported |
| NAT/STUN/ICE | Configure only from carrier/network guidance and verified SDK capabilities |
| Concurrent calls | Provider contract and SDK license limit |
| Timeout/retry | Must respect carrier limits and must not cause repeated unwanted contacts |

Do not infer port, transport, codecs, proxy or registration behavior from examples. Obtain these values from the SIP carrier.

## SMTP fields to confirm with the mail provider

| Field | Required information |
|---|---|
| SMTP host | Provider-supplied hostname |
| SMTP port | Provider-supplied port |
| Encryption | SSL/TLS or STARTTLS as documented by provider |
| Username | SMTP authentication identity |
| Password | App password or provider-approved secret |
| Sender address | Verified sender address |
| Display name | Approved sender display name |
| Recipient | Controlled test inbox before production |
| Timeout | Provider-supported timeout |

Do not disable TLS certificate validation. Do not log SMTP credentials or full message contents containing customer details.

## Local secret handling

Preferred storage order:
1. Windows Credential Manager or an enterprise-approved secret store.
2. A restricted-permission local configuration file outside the repository.
3. Environment variables injected at runtime by an approved launcher (only if a future application build explicitly supports them).

The included template deliberately uses REPLACE values and non-secret warnings. Never replace those with real secrets in a tracked file.

## Verification required before live use

- Verify carrier ownership/authority for outbound caller ID.
- Verify SIP registration succeeds with a real carrier test account.
- Verify supported codecs and successful two-way audio with an authorized test endpoint.
- Verify blind transfer with the actual provider; the vendor ReadMe specifically states this is a provider requirement.
- Verify SMTP STARTTLS or implicit TLS and authenticated test delivery.
- Verify calling hours, consent records, opt-out handling and retention controls before any campaign.
- Verify the exact legacy application's configuration format before writing any config into its settings file.
