# ADR 0006: Version Signal Activation Identity Scheme

## Status

Accepted

## Context

DepthMark materializes one row per triggered Gold signal output row in
`gold.signal_activations`. Downstream consumers use `signal_instance_id` to
refer to a stable activation occurrence, and match-level aggregates store arrays
of those IDs in `gold.signal_activations_match`.

The current activation builder derives each `signal_instance_id` from:

```text
SHA256("v1|<signal_id>|<row_identity values>")
```

where `row_identity` comes from the signal catalog frontmatter. The builder also
stores `signal_id_version = 'v1'`.

That `v1` value could mean two different things:

1. the version of the activation identity scheme; or
2. the version of the signal definition, including football logic, thresholds,
   SQL implementation, or authored catalog metadata.

Treating ordinary signal-definition changes as activation ID changes would make
reruns less stable and would churn downstream references even when the activated
row occurrence is the same. Treating the version as an identity-scheme version
keeps activation references stable, but requires a separate future mechanism if
DepthMark needs historical signal-definition versioning.

## Decision

DepthMark will treat `signal_id_version` as the signal activation identity
scheme version.

For the current scheme, activation IDs remain:

```text
SHA256("v1|<signal_id>|<row_identity values>")
```

The version prefix must stay at `v1` across reruns and ordinary changes to a
signal's SQL, thresholds, catalog text, or other signal-definition metadata, as
long as `signal_id` and the `row_identity` values that define the activated row
occurrence remain unchanged.

DepthMark may introduce a new identity scheme version, such as `v2`, only when
the activation identity contract intentionally changes. Examples include:

- changing hash serialization or delimiters;
- changing null handling or value normalization;
- changing required identity fields;
- changing what one activation row means;
- running a deliberate migration that needs old and new activation identities
  to coexist or be compared.

Signal-definition versioning, if needed, must be modeled separately from
`signal_instance_id` and `signal_id_version`.

Activation rebuilds remain full-table rebuilds for now. Because the identity is
deterministic, rerunning the activation builders should reproduce the same IDs
for the same active signal rows and identity values.

## Consequences

Downstream references to activation IDs stay stable across normal reruns and
signal logic refinements.

The activation ID has a narrower meaning: it identifies a triggered row
occurrence, not the semantic version of the authored signal.

Changing `row_identity` for an existing signal is a breaking identity-contract
change and should be treated as an explicit migration decision. It may require a
new identity scheme version, a compatibility plan, or both.

If DepthMark needs to audit or compare signal-definition changes over time, it
should add a separate catalog or signal-definition version field rather than
overloading `signal_id_version`.
