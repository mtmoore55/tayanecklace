# Taya Data Model

The source-of-truth reference for how captured speech becomes the structured content the app surfaces — Moments, Tasks, Notes, People, the daily Mirror, and everything else on Home.

This document defines the *mental model and the contracts*. It is deliberately implementation-agnostic (storage engine, LLM provider, on-device vs. server) so Taya's engineers can choose those independently. Where the current Swift package already gestures at this shape, it's called out under [Mapping to the current code](#mapping-to-the-current-code).

When this document and the prototype structs disagree, this document wins — the structs are demo scaffolding.

---

## 1. The core idea: a log and its projections

Taya has **two layers**, and keeping them separate is the whole design.

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2 — ENTITIES (projections)                            │
│  Tasks · Notes · People · Places · Themes · Daily Mirror     │
│  Mutable. Accumulate over time. Always recomputable.         │
└─────────────────────────────────────────────────────────────┘
                              ▲
                       extract · resolve · merge
                              │
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1 — MOMENTS (the log)                                 │
│  Append-only. Immutable. The ground truth.                   │
└─────────────────────────────────────────────────────────────┘
```

**Layer 1 — Moments.** Every capture is an immutable event: when, where from, what was said. The system **never edits a Moment** after distillation. It is the tape.

**Layer 2 — Entities.** Everything the user acts on — a task, a note, a person's profile, the morning summary — is a *projection* the LLM builds and maintains over the Moment log. Entities are mutable: they're created, enriched, and revised as new Moments arrive.

This is event-sourcing / CQRS applied to a memory product. Two properties fall out of it for free, and both are load-bearing for Taya:

- **Trust through provenance.** Every entity points back to the Moment(s) it came from, so the app can always answer "why are you telling me this?" by linking to the tape.
- **Safe reprocessing.** Because entities are derived, you can re-run extraction with a better prompt/model and rebuild Layer 2 without ever risking the user's raw captures.

> **Rule of thumb:** if a user said it, it's a Moment (immutable). If the app inferred it, it's an Entity (mutable, and must cite its Moments).

---

## 2. Layer 1 — The Moment

A Moment is one capture, distilled but never interpreted into action.

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Stable, permanent. |
| `createdAt` | Date | Capture time. |
| `source` | enum | `necklace` · `phone`. |
| `kind` | enum | `voice` · `note` · `journal`. How it was captured / its shape. |
| `title` | String | Short human label, LLM-generated. |
| `rawTranscript` | String | Verbatim. The actual ground truth — never overwritten. |
| `polishedSummary` | String | Lightly cleaned prose. A *presentation* of the transcript, not an interpretation. |
| `tags` | [String] | Coarse topical labels (cheap retrieval aid). |

**What a Moment is not:** it does not contain tasks, people, or decisions. Those are extracted *out* of it into Layer 2. A Moment is inert content; Entities are the live, actionable layer.

---

## 3. Layer 2 — Entities

Every entity shares a common contract, and that contract is what makes "create then update" work.

### The Entity contract

```
Entity {
  id            // stable, permanent
  ...type-specific fields...
  sourceMomentIDs: [UUID]   // provenance — every Moment that created OR updated this
  createdAt                 // first Moment that produced it
  updatedAt                 // most recent Moment that touched it
}
```

The non-negotiable part is `sourceMomentIDs`. A Task isn't "a task" — it's "the task that came from these two Moments." That backlink is what lets the UI show *from Tuesday's walk* and lets the user tap through to the tape.

### Entity types (today's set)

| Entity | Type-specific fields | Cardinality with Moments |
|---|---|---|
| **Task** | `text`, `status (open/done)`, `dueAt?`, `parentNoteID?` | created by one Moment, may be revised by later ones |
| **Note** | `title`, `body`, `relatedTaskIDs` | accumulates across many Moments |
| **Person** | `name`, `facts: [String]`, `aliases: [String]` | accumulates across many Moments |
| **Place** | `name`, `facts: [String]` | accumulates |
| **Theme** | `label`, `momentIDs` | a cluster, recomputed |
| **Mirror** (daily) | `date`, `prose`, `highlightedEntityIDs` | one per day, regenerated as the day fills |

Tasks are mostly create-and-complete; People/Notes/Places are the ones that genuinely *accumulate*. The Mirror is the reflective daily summary from the design review ("Yesterday was full —…").

---

## 4. The ingest pipeline

What happens, in order, when a Moment is recorded:

| # | Stage | Input → Output | Layer |
|---|---|---|---|
| 1 | **Capture** | hardware → audio | — |
| 2 | **Transcribe** | audio → `rawTranscript` | 1 |
| 3 | **Distill** | transcript → `title` + `polishedSummary` + `tags` | 1 |
| 4 | **Extract** | Moment → *candidate* entities (unresolved) | 1→2 |
| 5 | **Resolve & merge** | candidates → create new **or** update existing | 2 |
| 6 | **Recompute surfaces** | entities → Home, Mirror, badges | 2 |

Stages 1–3 produce the immutable Moment. Stages 4–6 build and revise Layer 2.

**The distinction that matters:** Stage 4 (Extract) *only ever proposes*. It looks at one Moment in isolation and emits candidates like `Task("reserve a table")` or `Person("Sarah")`. It has no memory. Stage 5 (Resolve & merge) is where memory lives — and it's the entire answer to "how does it get updated from a subsequent Moment."

---

## 5. Create vs. Update — the heart of it

For each candidate from Extract, Resolve asks one question: **have I seen this before?**

```
for candidate in extractedCandidates:
    match = resolve(candidate, against: existingEntities)
    if match == nil:
        create(candidate, provenance: [moment.id])          # CREATE
    else:
        merge(candidate, into: match)
        match.sourceMomentIDs.append(moment.id)              # UPDATE
        match.updatedAt = moment.createdAt
```

- **No match → CREATE.** A new entity, with this Moment as its origin.
- **Match → UPDATE.** Merge the new information into the existing entity and append this Moment to its provenance. The entity now cites *both* Moments.

That append-to-provenance step is why an entity can be "born" from one Moment and "grow" from the next. Extraction never updates anything; resolution does.

---

## 6. Worked example — Sarah's birthday

Two Moments, one Note that's created by the first and enriched by the second. (This is the exact flow behind the Home mockup.)

### Moment 1 — Tuesday, on a walk

> "…I keep meaning to do something for Sarah's birthday."

**Extract** proposes:
```json
[
  { "type": "Person", "name": "Sarah" },
  { "type": "Note", "title": "Sarah's birthday", "body": "Wants to do something for it." }
]
```
**Resolve:** neither exists yet → **CREATE both.**
```json
Person {  id: P1, name: "Sarah", facts: [], sourceMomentIDs: [M1] }
Note   {  id: N1, title: "Sarah's birthday",
          body: "Wants to do something for it.",
          relatedTaskIDs: [], sourceMomentIDs: [M1] }
```
**Home shows:** a soft note — *Sarah's birthday.*

### Moment 2 — Wednesday, on a call

> "…let's do dinner for Sarah's party, book a table for 12 at the new place, and I'll send the invite."

**Extract** proposes:
```json
[
  { "type": "Person", "name": "Sarah" },
  { "type": "Place",  "name": "the new place" },
  { "type": "Task",   "text": "Reserve a table for 12 for Sarah's party" },
  { "type": "Task",   "text": "Create invite for Sarah's party" }
]
```
**Resolve:**
- `Person "Sarah"` → **matches P1** → update (append M2 to provenance).
- The party content → **matches Note N1** → update its body, append M2.
- The two Tasks → no match → **CREATE**, each `parentNoteID = N1`.
- `Place "the new place"` → no match → CREATE.

**State after merge:**
```json
Note N1 {
  title: "Sarah's birthday",
  body:  "Dinner for Sarah's party. Table for 12 at the new place; send invite.",
  relatedTaskIDs: [T1, T2],
  sourceMomentIDs: [M1, M2],          // ← born Tuesday, grew Wednesday
  updatedAt: <Wed>
}
Task T1 { text: "Reserve a table for 12 …", status: open, parentNoteID: N1, sourceMomentIDs: [M2] }
Task T2 { text: "Create invite for Sarah's party", status: open, parentNoteID: N1, sourceMomentIDs: [M2] }
Person P1 { name: "Sarah", sourceMomentIDs: [M1, M2] }
```

**Home now shows** exactly the mockup: the Mirror mentions Sarah's birthday, and two checkboxes appear — *Make a reservation for 12 guests* and *Create invite for Sarah's party*. One Note, two Moments: created by the first, enriched by the second.

---

## 7. Open decisions for the team

The framework above is settled; these four are genuine product/engineering choices that shape the build:

1. **Matching strategy (Resolve).** How do we decide two mentions are the same entity? Options, roughly cheapest→best: exact name match → embedding similarity → an explicit LLM "are these the same?" pass → user confirmation for ambiguous cases. Likely a tiered combination.
2. **Conflict handling.** When a new Moment *contradicts* an existing fact ("Sarah's party is the 14th" → later "moved to the 21st"), do we overwrite, keep a version history, or flag for the user? Recommendation: overwrite the surfaced value, but keep provenance so the old Moment is still reachable.
3. **Cadence.** Incremental per-Moment (snappy tasks/notes, more LLM calls) vs. batch recompute (the nightly Mirror). Recommendation: both — per-Moment for actionable entities, a nightly pass for the reflective Mirror and theme clustering.
4. **Provenance granularity.** Minimum bar: every entity lists its Moment IDs. Nice-to-have: per-field provenance (which Moment set the `dueAt`), which makes "why?" answers precise but costs more bookkeeping.

---

## 8. Mapping to the current code

The prototype structs in `Sources/TayaCompanion/Models/` already point at this model — they're just incomplete:

| Concept | Current state | Gap to close |
|---|---|---|
| Moment (Layer 1) | `Moment` struct matches §2 well; fields are now `let`, so immutability is enforced by the type. | — done. |
| Entity contract | `Entity` protocol exists (`sourceMomentIDs`, `createdAt`, `updatedAt`, `merge(_:from:)`). `TaskItem` + `Person` conform. | Apply to the entity types still to be added (below). |
| Provenance | Generalized to `sourceMomentIDs: [UUID]` on every entity ✓. | — done for today's set. |
| Accumulating entity | `Person.facts: [String]` ✓, and `Person.mergeFields` unions them — the create-then-update shape is live. | Apply the same shape to Notes (which don't exist yet) and Places. |
| Task ↔ topic link | none. | Add `parentNoteID` so tasks belong to the Note/topic they serve. |
| Note entity | none. | Add it — it's the entity in Will's question. |
| Daily Mirror | none (Home shows static copy). | Add a per-day `Mirror` entity, regenerated as Moments land. |
| The pipeline (§4) | `DataStore.appendSyncedContent()` fakes the end result. | Real Extract/Resolve/Merge stages; this doc is the spec. |

**Done:** Layer 1 is immutable and Layer 2 has a shared `Entity` contract (`sourceMomentIDs` + `merge`), so the scaffolding now matches this framework. **Next:** add the missing entity types (Note, Place, Mirror) on top of the contract, then build the real Extract → Resolve → Merge pipeline (§4–5) in place of the faked sync.
