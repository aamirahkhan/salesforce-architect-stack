# ADR 0004 — Record-based logging

- **Status:** Accepted
- **Date:** 2026-11-01
- **Deciders:** Salesforce architecture

## Context

Salesforce debug logs expire (typically within a day) and are limited in size. When an integration fails
at 2am, the log is usually gone before anyone investigates. Error emails are unstructured, and some
orgs disable them entirely.

The platform offers several sinks: a custom log object, Platform Events with an external subscriber,
`System.debug` plus a log retention tool, or an external observability vendor. Each has a different
durability and access model.

## Decision

Write structured entries to `ApplicationLog__c` through `LogService`:

- Entries are buffered and inserted in bulk on `flush()` to stay inside DML limits.
- Inserts run in **system mode** so telemetry does not depend on the permissions of the user who
  triggered the failure.
- Entries capture level, source, message, exception type, line number, stack trace, related record id,
  correlation id and an optional JSON payload.
- Logging never throws. A failed log insert writes to the debug log and is otherwise ignored.
- `TriggerDispatcher` and the async job bases log unhandled failures and flush before rethrowing.

### Known limitation

If the surrounding transaction rolls back, its logs roll back with it. That is a property of writing to
a record in the same transaction. The stack accepts it because record logs cover the common case — a
failure that is caught and handled, or a partial batch scope that fails while the rest commits.

When logs must survive a rollback, publish a Platform Event and persist it in a separate transaction, or
stream to an external sink. The `LogService` boundary makes that swap local.

## Consequences

**Positive**

- Logs are searchable, reportable and permissionable. Support can find "every failure for this
  integration user in the last hour" without a debug log session.
- No external dependency, no callout, no API key. Works in every org from day one.
- Correlation ids tie together multi-step integrations.
- Storage is bounded by a retention policy the team controls.

**Negative**

- Logs written in a rolled-back transaction are lost.
- The log object consumes data storage. A retention policy and a scheduled purge are required in
  production.
- System-mode writes bypass FLS by design. The service must therefore never receive secrets, full
  payloads with personal data, or credentials. `Payload__c` is for context, not data dumps.
- Logging inside a trigger adds a DML statement if it flushes. The dispatcher flushes only on failure.

## Alternatives considered

**Platform Events + external subscriber.** Survives rollback and scales, but requires infrastructure
and a subscriber before any value is delivered. Reasonable as a later upgrade; overkill as a baseline.

**`System.debug` only.** Free and zero storage, but expires and cannot be queried.

**Third-party observability (Splunk, Datadog, New Relic).** Good for mature platform teams, but adds a
vendor, a credential and a deployment dependency to a baseline every org should be able to adopt.

## References

- [Architecture — observability](../ARCHITECTURE.md)
- `LogService`, `ApplicationLog__c`
