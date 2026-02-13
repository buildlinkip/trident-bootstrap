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
