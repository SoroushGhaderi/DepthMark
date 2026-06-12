# Context

## Glossary

### Signal Activation

A Gold metadata row that records one triggered signal output row for one match,
team, or player occurrence.

Related terms: Signal, Signal Catalog, Signal Activation ID.

### Signal Activation ID

A deterministic identifier for one signal activation. It is derived from the
activation identity scheme version, `signal_id`, and the catalog `row_identity`
values. It identifies the activated row occurrence, not the version of the
signal's football logic.

Avoid saying: signal version, catalog version.
Related terms: Signal Activation, Signal Identity Scheme Version, Signal
Definition Version.

### Signal Identity Scheme Version

The version prefix used in signal activation ID hashing, currently `v1`. It
changes only when DepthMark intentionally changes the activation identity
contract, such as hash serialization, required identity fields, null handling,
or the meaning of one activation row.

Avoid saying: signal definition version.
Related terms: Signal Activation ID, row_identity.

### Signal Definition Version

A future catalog concern for tracking changes to a signal's football logic,
thresholds, SQL implementation, or authored metadata. It is separate from signal
activation identity.

Related terms: Signal Catalog, Signal Activation ID.

### Signal Catalog

A markdown-authored description of one Gold signal, including frontmatter
metadata and human-readable explanation. The catalog frontmatter is the
canonical source for signal metadata that is synchronized into MongoDB.

Related terms: Signal Activation, Signal Catalog Sync.

### Signal Catalog Sync

The process that reads markdown signal catalogs and writes derivative documents
to the MongoDB `signals` collection for serving and querying.

Avoid saying: Mongo catalog authoring.
Related terms: Signal Catalog.
