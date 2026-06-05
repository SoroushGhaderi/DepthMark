# Gold Signal Contract Index

The original monolithic contract has been split into two purpose-specific contracts:

1. Core creative contract (Codex High):
   - `scripts/gold/signal/contracts/SIGNAL_CORE_CONTRACT.md`
2. Routine implementation contract (Codex Low):
   - `scripts/gold/signal/contracts/SIGNAL_EXECUTION_CONTRACT.md`

## Normative Language

These terms apply across both contracts:

- `MUST`: mandatory for production readiness.
- `SHOULD`: strong recommendation; exceptions require clear rationale.
- `MAY`: optional.

## Which Contract To Use

Use `SIGNAL_CORE_CONTRACT.md` when the task requires:

- writing or refining signal SQL logic
- designing analyst query outputs
- producing or improving signal catalogs

Use `SIGNAL_EXECUTION_CONTRACT.md` when the task requires:

- creating/updating signal tables
- wiring generic SQL execution
- wiring bulk execution and release checks

Both contracts are normative and complementary; a complete signal package must satisfy both.

## Signal Similarity Gate (summary)

Before implementing any new signal, a similarity check against existing active signals is mandatory.
See `SIGNAL_CORE_CONTRACT.md` § Signal Similarity Gate for the full rule.

## Naming and Consistency

A single canonical naming contract applies to all signal assets.
See `SIGNAL_EXECUTION_CONTRACT.md` § Naming and Consistency Contract.
