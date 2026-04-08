# Runtime Host Support

This module contains the Batch 3 runtime lane support for an Xcode-hosted Endpoint Security app or system extension.

Current responsibilities:

- own the live `es_new_client` and `es_subscribe` lifecycle
- route real callbacks into `EndpointSecurityProcessAttributedEventSubscriber`
- expose a higher-level `EndpointSecurityRuntimeCoordinator` so the host target can wire scopes and evaluation handling without duplicating glue code

This module is intended for Xcode-linked runtime hosts. It does not remove the entitlement, signing, or approval requirements for live Endpoint Security monitoring.
