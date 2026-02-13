# Contributing to TRIDENT Bootstrap

Thank you for your interest in contributing to TRIDENT Bootstrap.

TRIDENT is a governance‑first system. All contributions must preserve:

- Provenance  
- Isolation  
- Determinism  
- Auditability  
- Operator safety  
- Minimal blast radius  

These principles are non‑negotiable and define the purpose of the project.

---

## How to Contribute

1. **Fork** the repository  
2. **Create a feature branch**  
3. Make your changes  
4. Ensure the bootstrap still:
   - logs deterministically  
   - maintains hash chaining  
   - enforces isolation gates  
   - respects privilege boundaries  
   - requires explicit human overrides  
5. Submit a **pull request**

All PRs must include:

- A clear description of the change  
- Rationale for the change  
- Any security implications  
- Confirmation that the bootstrap still runs cleanly end‑to‑end  

---

## Code Style

- Bash only  
- No external dependencies beyond:
  - `jq`
  - `sha256sum`
  - standard POSIX tools  
- No silent failures  
- Every decision must be logged  
- Every gate must be explicit  
- No hidden behavior  
- No automatic privilege escalation  

---

## Governance Requirements

Any contribution that touches:

- privilege checks  
- isolation logic  
- override gates  
- provenance chain  
- logging format  
- execution control  

…must be reviewed under the **Security Advisory** process instead of a normal PR.

---

## Testing

Before submitting a PR:

1. Run the bootstrap from a clean directory  
2. Run it from `$HOME` (should escalate)  
3. Run it from `/tmp` (should escalate)  
4. Run it without Node installed (should deny)  
5. Run it without Docker installed (should escalate)  
6. Verify the hash chain is valid and append‑only  

---

## Philosophy

TRIDENT is not an installer.  
It is a **governance kernel**.

Contributions must strengthen:

- clarity  
- safety  
- auditability  
- determinism  
- operator trust  

If a change introduces ambiguity or reduces safety, it will not be accepted.

---

## Contact

For security‑sensitive changes, see `SECURITY.md`.
