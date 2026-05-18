# NeuroPulse roadmap and candid status

## Current state

NeuroPulse is a real library, but it is still an extraction in progress.

It already provides a useful routing core:
- spike-density scoring
- EMA-based surprise tracking
- momentum-aware routing updates
- inhibition and normalization

At the same time, it still needs substantial work before it reaches the fuller long-term
shape rmems wants.

## What still needs work

### 1. Naming cleanup

The repository/package name is now `NeuroPulse`, but parts of the API still expose older
NERO-specific naming.

Examples:
- `NeroOrchestrator`
- `nero_diagnostics`
- `NERO_*` constants

That is acceptable for now, but likely not the final naming scheme.

### 2. Default assumptions are still historical

The default lobe names are:
- `Attention`
- `FFN`
- `Memory`
- `Output`

Those are useful examples, but they imply a specific older context. Future cleanup should
separate example defaults from the core conceptual model.

### 3. Stress adaptation is too narrowly framed

`adapt_leak!` currently assumes a fan-speed-like stress input. That is fine as a helper,
but the long-term package boundary may want either:
- a more generic stress adapter API, or
- moving that helper into a separate integration layer

### 4. Configuration surface is still minimal

Current tuning constants are hardcoded in source. That keeps the library simple, but it
limits experimentation with:
- alternate scoring weights
- alternate inhibition matrices
- different floor/normalization policies

### 5. Documentation still needs to grow with the API

This README/docs pass is a cleanup step, not the end state. Useful future docs would include:
- worked examples for custom component layouts
- adapter guidance for reservoir systems
- design notes on choosing spike-rate normalization
- stability notes for long-running routing loops

## Desired long-term direction

A stronger future NeuroPulse would look like this:

- clean package identity with generalized naming
- explicit ownership boundaries
- neutral examples by default
- configurable routing/inhibition policies
- clearer interop contracts with upstream SNN and reservoir libraries
- documentation that describes both current behavior and intended evolution

## What this library should remain

Even after more work, NeuroPulse should remain small.

It should be a routing/relevance library, not a monolithic platform.
That means future growth should sharpen the boundary rather than blur it.
