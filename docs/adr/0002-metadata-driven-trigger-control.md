# ADR 0002 — Metadata-driven trigger control

- **Status:** Accepted
- **Date:** 2026-11-01
- **Deciders:** Salesforce architecture

## Context

Triggers fail at the worst moments: a data migration hits a validation rule, an integration user lacks
a related record, a backfill needs to run without the after-update handler. The usual responses are a
hotfix deployment, a hardcoded bypass flag, or an admin asking someone to comment out code.

All three are worse than the problem. Deployments take time, hardcoded flags are invisible, and
commented-out code is a production incident waiting for the next release.

## Decision

Evaluate bypass in three layers, in order:

1. **Runtime bypass** — `TriggerHandler.bypass('AccountTriggerHandler')` for tests and controlled
   scripts inside one transaction.
2. **Metadata disable** — a `TriggerSetting__mdt` record whose `Is_Active__c` is false disables the
   handler in that environment. No deployment.
3. **Custom permission** — `Bypass_Custom_Permission__c` names a custom permission. Users holding it
   bypass the handler, which is how integration users run data loads.

Settings are cached once per transaction, keyed by handler class name. A missing record means the
handler is active; the framework fails open.

## Consequences

**Positive**

- A handler can be disabled in production by an admin, with an audit trail in Setup Audit Trail.
- Data loads can bypass validation deliberately, without changing code.
- The bypass is visible in metadata review and travels between environments.
- Tests can disable a handler without deploying or editing CMT.

**Negative**

- One extra SOQL per transaction that fires a trigger (cached afterwards).
- The bypass is per handler, not per record or per operation. A bypassed handler skips all its contexts.
- An admin can disable a handler and forget to re-enable it. Mitigation: a list view of disabled
  trigger settings and a CI check that the shipped records are active.
- Metadata evaluation runs before the trigger body, so a syntax error in a handler still fails at
  compile time; a misconfigured record can only disable, not alter, behaviour.

## Alternatives considered

**Custom setting with a Boolean per handler.** Faster to read and cacheable, but custom settings are
not deployable as metadata records in the same reviewable way, and environment-specific values drift
silently.

**Permission-based bypass only.** Clean, but does not let an admin stop a misbehaving handler during an
incident without a deployment.

**Hierarchy custom setting / feature flag service.** Adds a layer without solving the per-handler
problem; custom metadata is the native, deployable answer.

## References

- [Architecture — trigger control](../ARCHITECTURE.md)
- `TriggerControl`, `TriggerSetting__mdt`
