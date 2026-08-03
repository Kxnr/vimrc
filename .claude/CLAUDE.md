# Communication Style

- **Be concise.** Prefer one sentence over a paragraph. Prefer a bullet over prose.
- **No preamble.** State findings and decisions directly — skip "I'll now..." narration.
- **No trailing summaries.** The diff speaks for itself.
- **Bullets and headers** for structure, but keep each section short (2–4 lines max).
- **Assume follow-up.** I'll ask if I need more detail; default to less.

# Information Layering

Applies to code, prose, and my own replies. Each rule below assumes the ones above it.
- **Scope conflict:** in a chat reply, "answer-first / concise" (above) overrides "general → specific" (below).
- **Procedure:** before writing a non-trivial artifact, name the model and reading order of each level, then write to that plan. This is how the rules below actually fire — they are hard to satisfy token-by-token without committing first.

## Model the problem, not the editor — the root

Express a model of the problem, not the convenience of editing text. A problem rarely dictates one structure: a diagonal slider can be modeled as composed x/y motion, a rotation of the coordinate frame, a point-slope line, or one opaque component — each internally valid. Choosing among them is the design act, judged by two things: **fit** (which model matches how the domain thinks) and **leverage** (which model is the best building block for what you'll build next). Get this right and low coupling and easy change fall out; chase those directly and you get clever structure that fights the problem.

- **A valid model may not decompose at all.** A cohesive opaque unit beats any split when the problem has no internal seam worth exposing.
- **Merge what is the *same* in the problem; separate what is *distinct*** — regardless of how alike the code looks on the page.
- **Cohesion: what models one thing lives together.** Split at a problem seam, not because a file grew long.
- **Duplication beats false unity.** Copy-pasting a function is usually more correct than one function with six flags steering its behavior across scenarios. Don't factor to save typing.
- **Naming is cheap; factoring is dear.** A bad name is one rename away; a bad decomposition is a rewrite. Spend judgment on the seams, not the labels.

## Minimize information across a boundary

This is what a good model buys you, and the test of one: a unit depends only on what's already established — never on what comes later, nor on the context that will use it. The mechanical tells:

- **One home for a cross-cutting concern** (logging, counting, errors, config). Smeared through every unit, it's a puddle.
- **Compute, then act.** Finish a result before an outer layer does I/O on it; the shell never reaches into the core mid-computation.
- **Return facts, not verdicts.** A rich result lets each caller decide; a caller-specific verdict has absorbed someone else's concern.

## There is always a reading order

A reader is linear even when the structure branches. Reading code is an A\* search — descend into a unit, understand it, return, move across.

- **Every node summarizes its subtree** well enough to decide whether to descend; after returning, you should need to remember nothing about its internals (call-site amnesia).
- **Prose** descends top to bottom, general → specific: broad claim, then support.
- **Code** is entered at the top and read by diving in and returning — so the top reads like a table of contents and each unit stands alone. Same rule, both ends.

## Complexity lives high, leaves stay simple — not fractal

- **A small unit has one behavior.** No flow-control zoo, no mode flags.
- **A large unit may combine operations** — flow control, similar-but-different orderings — but only through well-constructed orthogonal sub-units, so the combination stays legible.
- **Form follows level.** High levels look alike (orchestration, framing); low levels fit their specific job. Switch paradigms between levels when it helps — an object-oriented shell around a functional core is good design. No paradigm is universal.
- **Match depth to size.** Keep small things flat; add hierarchy only when content demands it. Over-structuring is as wrong as flattening.

## Every level has a voice

A level speaks one consistent, nameable model of its slice — "this is a state machine," "a pipeline," "a repository" — so a reader can predict its shape and rely on it.

- **Commit to the model.** An unapologetic state machine is clear precisely because it commits: consistent vocabulary, predictable transitions, even at the cost of awkward corners. Code turns incomprehensible when practices are mixed to patch local problems — each defensible alone, incoherent together.
- **A sub-component may take its own voice, but only at a scope large enough to be recognized** and used to assume what's inside.

Reference — `Repository` / `Backend` in `core_data`. `Backend` speaks pure storage: `save`/`load`/`delete`/`lock`, unconditional, no business logic, every backend interchangeable. `Repository` speaks business rules: invariants, conflict resolution. Two voices, each consistent, repeated identically across bids, configs, and outages. Not necessarily optimal — but predictable, so you always know where you are.

## Place each change at its own level

Hold the whole structure in mind, find the level where a change belongs, and keep it there. If it won't stay contained — it forces edits up and down the hierarchy — that's a signal, not a chore: the change is at the wrong level, or the model no longer fits the problem. Stop, re-understand the problem, and re-plan before continuing.

**Exception — imposed coupling.** Bug fixes, compatibility shims, external-system quirks, and hard performance limits sometimes force a unit to reference the larger context. That coupling is imposed, not chosen — mark it with a comment explaining *why*, so it stands out as deliberate.
