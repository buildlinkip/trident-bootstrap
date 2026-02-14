# **TRIDENT Bootstrap v0.3**

<p align="center">
  <img src="https://github.com/user-attachments/assets/d8636e10-0c73-4f61-a57d-fdf3e20341d2" width="200">
</p>

TRIDENT Bootstrap is a governance‑first initialization system that enforces provenance, isolation, safety, and controlled execution **before any autonomous system or automation stack is allowed to run**.

v0.3 transforms the bootstrap from a static preflight script into a **self‑diagnosing, self‑repairing governance kernel** that prepares an operator‑grade environment with deterministic behavior and zero silent failures.

TRIDENT is not an installer.  
It is the **boundary layer** that ensures installers and agents operate inside law, structure, and auditability.

---

## **Badges**

`https://img.shields.io/badge/License-MIT-green.svg`
`https://img.shields.io/badge/Governance-Kernel-blue.svg`
`https://img.shields.io/badge/Self--Repairing-orange.svg`
`https://img.shields.io/badge/WSL-Safe-informational.svg`
`https://img.shields.io/badge/Language-Bash-yellow.svg`

---

# **What’s New in v0.3**

TRIDENT Bootstrap v0.3 introduces a full architectural upgrade:

### **✔ Filesystem Gate (NEW)**
Detects unsafe WSL DrvFS execution and blocks venv/symlink corruption.  
Offers guided migration to `/opt/trident-bootstrap`.

### **✔ Dependency Auto‑Install (NEW)**
Automatically installs:
- `jq`
- `curl`
- Python venv modules
- Node.js 22.x (via NodeSource)
- Docker (optional)

All with explicit human approval and provenance logging.

### **✔ Venv Integrity Gate (UPGRADED)**
Validates:
- activation scripts  
- Python version alignment  
- pyvenv.cfg  
- filesystem type  
- corruption or partial installs  

Auto‑repairs when needed.

### **✔ Node.js Auto‑Upgrade (UPGRADED)**
Detects outdated Node versions and performs a governed upgrade to Node.js 22.x.

### **✔ Doctor Mode (NEW)**
```
./trident-prep.sh --doctor
```
Runs a full environment scan + auto‑repair without executing the full bootstrap.

### **✔ State Cache (NEW)**
Stores:
- python version  
- node version  
- venv path  
- filesystem type  

Ensures deterministic re‑runs.

### **✔ Narration Overhaul**
Every decision is narrated in TRIDENT doctrine voice.  
No silent failures. No invisible actions.

---

# **Why TRIDENT Exists**

Autonomous systems are accelerating faster than the guardrails meant to contain them. Agents can act, mutate state, and propagate consequences at machine speed — but most environments still assume human‑paced failure modes.

This mismatch is structural.

TRIDENT exists to impose **law, structure, and legibility** on autonomous execution. It enforces seven non‑negotiable guarantees:

- **Traceability** — no ghost states  
- **Restriction** — no unbounded authority  
- **Integrity** — no rewriting history  
- **Determinism** — no unpredictable outcomes  
- **Enforcement** — no bypass paths  
- **Narration** — no unreadable failures  
- **Trust** — no permanent privilege  

Autonomous systems shall operate inside law,  
or they shall not operate at all.

TRIDENT is the control plane that makes autonomy survivable.

---

# **Architecture Overview**

TRIDENT sits between agent cognition and real‑world execution.  
Every action must pass through the **Five Gate Pipeline**:

**Intent → Policy → Risk → Execution → Ledger**  
**G1 → G2 → G3 → G4 → G5**

### **Gate Summary**

| Gate | Name | Purpose |
|------|------|---------|
| **G1** | Intent Capture | Declares objective and provenance |
| **G2** | Policy Evaluation | Determines legality and authorization |
| **G3** | Risk Scoring | Models impact and failure domains |
| **G4** | Controlled Execution | Sandboxed, scoped, reversible |
| **G5** | Forensic Recording | Immutable, append‑only ledger |

TRIDENT guarantees:

- no silent failures  
- no invisible actions  
- no ungoverned execution  

---

# **Bootstrap Features (v0.3)**

### **Filesystem Gate**
Blocks unsafe execution on WSL DrvFS.  
Ensures venvs, symlinks, and permissions behave predictably.

### **Dependency Gate**
Auto‑installs missing prerequisites with explicit human approval.

### **Venv Integrity Gate**
Creates, validates, or repairs Python virtual environments.

### **Node.js Gate**
Requires Node.js 22+.  
Auto‑upgrades when needed.

### **Docker Gate**
Optional but recommended for strong sandboxing.

### **Intent Capture**
Binds the bootstrap to a human actor and purpose.

### **Append‑Only Provenance Ledger**
Every decision is hashed and chained for tamper‑evidence.

---

# **Quick Start**

### **1. Clone the repository**
```
git clone https://github.com/YOURNAME/trident-bootstrap.git
cd trident-bootstrap
```

### **2. Make the script executable**
```
chmod +x trident-prep.sh
```

### **3. Run the bootstrap**
```
./trident-prep.sh
```

---

# **Recommended Directory**

TRIDENT should run from a stable, isolated path:

```
sudo mkdir -p /opt/trident-bootstrap
sudo chown -R $USER:$USER /opt/trident-bootstrap
```

---

# **Roadmap**

### **v0.4 — Policy Module Loader**
Load and enforce external rule sets.

### **v0.5 — Actor Registry**
Identity binding for humans and agents.

### **v0.6 — Intent Capsule Simulator**
Simulate intent → policy → risk → execution.

### **v0.7 — Sandbox Hooks**
Capability tokens, fuel metering, and execution envelopes.

### **v1.0 — Full Governance Kernel**
Complete Five Gate Pipeline with HITL escalation.

---

# **License**
MIT License.

---

# **Contributing**
PRs welcome. Governance‑aligned contributions preferred.

---

# **Status**
Active development.  
TRIDENT is evolving into a full governance kernel for BuildLink and autonomous systems.
