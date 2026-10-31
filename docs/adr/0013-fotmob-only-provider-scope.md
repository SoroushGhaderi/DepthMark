# ADR 0013: FotMob-Only Provider Scope

## Status

Superseded by ADR 0021

## Context

The codebase contains generic-looking abstractions: `BaseBronzeStorage` ABC with
abstract `scraper_name`/`source_name` properties, a `--skip-fotmob` pipeline
flag, and FotMob-specific classes namespaced under `src/fotmob/`. The
architecture docs already state "DepthMark is a FotMob-only medallion pipeline,"
but the abstract base class implies a provider plugin surface.

Adding a provider abstraction without a concrete second provider to validate
against would be speculative, hard to reverse, and create maintenance burden for
a feature that does not yet exist.

## Decision

DepthMark is FotMob-only. The `BaseBronzeStorage` ABC and similar generic-looking
layers are FotMob-specific implementation details, not a provider plugin
contract. No provider abstraction boundary exists or will be added until a
concrete second provider needs to be supported.

The `--skip-fotmob` flag remains as a pipeline convenience for running Bronze-only
or Silver/Gold-only runs without re-scraping, not as evidence of multi-provider
intent.

## Consequences

Benefits:
- No speculative abstraction to maintain or test.
- FotMob-specific behavior stays local and explicit.
- Code that looks generic is documented as FotMob-specific, reducing confusion.

Costs:
- When a second provider arrives, some refactoring will be needed to introduce
  the abstraction boundary cleanly.

Follow-up constraints:
- A second provider abstraction must be introduced alongside a concrete second
  provider, not preemptively.
- The decision to add a second provider should be captured in a new ADR.

## Update (2026-10-31)

`--skip-fotmob` turned out to skip every pipeline stage, so it was a no-op
rather than a convenience. It is deprecated (removed in DepthMark 3.0.0); use
the `--skip-*` and `--*-only` stage flags. The pipeline no longer carries
`skip_fotmob` or `scraper="fotmob"` parameters.

