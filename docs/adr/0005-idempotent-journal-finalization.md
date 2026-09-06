# ADR 0005: Idempotent journal finalization

Status: accepted

## Context

Journal finalization coordinates journal storage, companion growth, and cleanup across multiple Repositories. A process or storage failure can occur after one step succeeds, so retrying the whole ViewModel command must not create another journal entry or apply the same observations twice.

## Decision

- Use the exploration ID as the idempotency key for journal entries and companion updates.
- Return the existing journal entry when the same exploration is saved again.
- Persist companion state and applied exploration IDs in one database value so they change atomically.
- Delete persisted active exploration and observation values before clearing their in-memory copies, preserving retry inputs when cleanup fails.
- Keep orchestration in `JournalViewModel`; do not introduce Repository-to-Repository dependencies.

## Consequences

A failed finalization can be retried safely across ViewModel calls and application restarts. Existing companion JSON without applied exploration IDs remains readable and is upgraded on the next successful update. The applied ID list grows with journal history and can be compacted together with future archival or sync work.
