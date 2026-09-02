# Orchestra membership — quorum

> **This project (quorum) is a MEMBER of the Orchestra** (one
> coordination structure; reconciled 2026-06-03). The leader-node is
> **ORCHESTRA_dev** (governance, roster, contracts, TACI, publication); the
> technical inference hub is **flexyBayes** (the dependency-DAG sink). This file is
> quorum's back-pointer to that charter and a map of my siblings.

- **My role:** the **composition / glue layer** (`Imports: flexyBayes`) — I own no
  inference math of my own; I turn member outputs into shared contract objects so
  the federation composes without any member depending on another's internals, and
  I keep the flexyBayes core lean. I carry: surrogate emulators, ensemble sources,
  ensemble-derived priors, the **activated koine fourth-opinion backend**
  (`emit_koine`), and the koine genomic oracle (`koine_genomic_lens`, sommer,
  Suggests-only).
- **Contracts I own / honour:** I am the contract **hub** — I **consume** PESTO's
  **C2** `pesto_ensemble_manifest` and produce the canonical `fb_ensemble` (**C5**);
  I conform `fb_surrogate` (**C7**); I adapt koine (**C3**) into flexyBayes'
  `triangulate`/`triangulate_genomic` via S3 methods on core's generics (no core
  edit).
- **My edge:** adapter — I sit beside flexyBayes, lifting PESTO/koine/kernR outputs
  into the shared objects flexyBayes consumes. Acyclic: I depend on flexyBayes
  (and contracts), never the reverse.
- **What binds me (charter invariants):** *depend on contracts, never member
  internals* (each seam stays standalone-functional when the richer member is
  absent); *honest abstention/gating* (`as_fb_ensemble` errors with an actionable
  message on an unknown class; the koine + genomic-lens slots are Suggests-/option-
  gated); *leader-directed adoption*.
- **Governance:** quorum is a **Max-owned personal package**
  (`max578`, MIT-track); the AAGI-AUS canon does not apply (it Imports flexyBayes
  but is itself a personal composition layer).

## My siblings (the full roster — so I am informed about the others)

| Member | Role | Class |
|---|---|---|
| flexyBayes | inference hub (owns C1/C4/C5/C7) | open (AAGI-gated) |
| PESTO | calibration + manifest source (C2) | open |
| kernR | validation + TACI/ACI engine | open |
| proxymix | KL-optimal proxy compression; the `proxymix_map` optimisation engine | open |
| gretaR | engine — torch MCMC | open |
| koine | synthesis — fourth opinion | open |
| terroir | data collector (C6) | open (MIT) |
| kalmix | state-space / change-point / ACI | open (MIT) |
| masque | data sovereignty (clones) | open |
| apsimR | external engine — APSIM Next Gen | open (MIT-src) |
| bourse | grounded market-data connector (trading arm) | open |
| survkit | time-to-event toolkit | open |
| janusplot | asymmetric GAM association matrices (diagnostic-viz) | open |
| gpfield | change-of-support spatial GP; emits `orchestra_manifest` | open (MIT) |
| decideR | decision layer (loss-optimal closer) | open |
| grainPlan | grain decision-orchestration (on decideR) | open (MIT) |
| optimix | optimisation meta-layer; emits `orchestra_manifest` | open (MIT) |
| quorum | **composition layer (this package; surrogates, koine backend)** | open |

Planned: genoR. **Canonical charter:** `ORCHESTRA_dev/ORCHESTRA.md` (mirrored in
the MaxAIbase brain, open tier). **Contract + dependency DAG:**
`ORCHESTRA_dev/integration/orchestra_manifest.R`.
