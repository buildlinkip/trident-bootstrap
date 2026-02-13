# Security Policy

## Supported Versions

TRIDENT Bootstrap v0.2 is the current supported version.

Security updates and fixes apply only to the latest tagged release.

---

## Reporting a Vulnerability

If you discover a vulnerability related to:

- privilege escalation  
- bypassing isolation gates  
- tampering with the hash chain  
- unsafe overrides  
- uncontrolled execution  
- provenance spoofing  
- directory traversal  
- environment poisoning  

Please **do not** open a public GitHub issue.

Instead, submit a **private security advisory** through GitHub’s Security tab.

This ensures responsible disclosure and protects downstream users.

---

## Scope

TRIDENT enforces:

- provenance  
- isolation  
- deterministic logging  
- controlled execution  
- human‑in‑the‑loop overrides  
- minimal blast radius  

Any bypass of these principles is considered a security issue.

---

## Out of Scope

The following are not considered vulnerabilities:

- User misconfiguration  
- Running TRIDENT as root  
- Running TRIDENT from unsupported directories  
- Missing optional dependencies (e.g., Docker)  
- External installer failures (e.g., OpenClaw script issues)  

---

## Security Philosophy

TRIDENT is built on the idea that:

> “Governance is not optional. Safety is not a feature.  
>  Provenance is the foundation of trust.”

The bootstrap is intentionally strict.  
Any deviation from deterministic, auditable behavior is treated as a potential security concern.

---

## Contact

Use GitHub’s private advisory system for all security reports.
