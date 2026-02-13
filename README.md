# TRIDENT Bootstrap v0.2

TRIDENT Bootstrap is a governance-first initialization process that enforces
provenance, isolation, safety, and controlled execution before any automation
or AI system is installed or run.

This project provides:

- A governed bootstrap flow
- Tamper-evident append-only logging
- Isolation and privilege gates
- Node.js and Python environment validation
- Human override gates with provenance capture
- A deterministic, auditable installer wrapper

TRIDENT is not an installer.  
It is a **governance kernel** that wraps installers in safety, auditability, and intent.

---

## Why TRIDENT exists

Autonomy is accelerating faster than governance. Modern agents can act, decide, and propagate consequences at machine speed, but the systems meant to contain them still operate on human assumptions. This gap is not theoretical. It is structural. And it is dangerous.

TRIDENT exists because **autonomy without governance is fragility**, a point made explicit in the doctrine:

> Autonomy without governance is a liability. Speed without structure is fragility. Power without constraint is a threat.

Unchecked agents drift. They accumulate privilege. They mutate state. They create ghost operations that cannot be reconstructed or audited. They fail silently, and silent failures compound. TRIDENT is the counterforce — engineered friction at the exact points where friction prevents catastrophe.

The doctrine frames this as **survival architecture**, not bureaucracy:

> TRIDENT applies engineered compression. Deliberate friction at the points where friction prevents catastrophe.

TRIDENT exists to impose **law, structure, and legibility** on autonomous execution. It transforms raw capability into governed capability by enforcing seven non‑negotiable properties:

- **Traceability:** no ghost states  
- **Restriction:** no unbounded authority  
- **Integrity:** no rewriting history  
- **Determinism:** no unpredictable outcomes  
- **Enforcement:** no bypass paths  
- **Narration:** no unreadable failures  
- **Trust:** no permanent privilege  

These are not features. They are constitutional guarantees.

The doctrine states the mandate plainly:

> Autonomous systems shall operate inside law, or they shall not operate at all.

TRIDENT exists because enterprises need a **control plane for autonomy** — a governance kernel that captures intent, evaluates policy, scores risk, constrains execution, and commits an immutable forensic record. It is the infrastructure that makes autonomy survivable, auditable, and deployable at scale.

Autonomous agents are inevitable.  
Uncontrolled agents are unacceptable.  
TRIDENT is the boundary between the two.

---

## Features

### Provenance Chain
Every action is logged with:
- timestamp  
- script version  
- decision (PERMIT / DENY / ESCALATE / OVERRIDE)  
- rationale  
- previous hash (for tamper-evidence)

### Isolation Gates
The bootstrap escalates or denies if run from:
- `$HOME`
- `/root`
- `/tmp`

Recommended path:

```
/opt/trident-bootstrap
```

### Python Venv Preflight
Ensures:
- Python3 exists  
- venv module exists  
- venv is created or reused  
- execution is isolated  

### Node.js Gate
Requires Node.js **22+**.

### Docker Gate (optional)
Strengthens sandboxing but can be overridden.

### Intent Capture
Binds the bootstrap to a human actor and purpose.

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/YOURNAME/trident-bootstrap.git
cd trident-bootstrap
```

### 2. Make the script executable

```bash
chmod +x trident-prep.sh
```

### 3. Run the bootstrap

```bash
./trident-prep.sh
```

---

## Directory Recommendation

TRIDENT should be run from a dedicated, isolated directory:

```bash
sudo mkdir -p /opt/trident-bootstrap
sudo chown -R $USER:$USER /opt/trident-bootstrap
```

---

## License

MIT License. See `LICENSE` for details.

---

## Security

See `SECURITY.md`.

---

## Contributing

See `CONTRIBUTING.md`.

---

## Status

Active development.  
TRIDENT is evolving into a full governance kernel for BuildLink and related systems.
