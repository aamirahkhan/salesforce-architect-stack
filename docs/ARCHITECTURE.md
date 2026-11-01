# Architecture

## Goals

1. A new feature has exactly one obvious place to live.
2. Security is the default, not a review comment.
3. A failure is traceable after the debug log has expired.
4. Adding a trigger does not mean adding a new flavour of trigger framework.
5. Every rule is testable without an org-specific data set.

## Non-goals

- Replacing the Salesforce platform's own features (validation rules, flows, permissions).
- A generic ORM. Salesforce's SObject model is already the ORM.
- Framework purity. Every abstraction here earns its place by removing a specific recurring bug.

## Layers

```
┌──────────────────────────────────────────────────────────────────────┐
│ Entry points: trigger, @AuraEnabled, Flow, REST, async job            │
└───────────────┬──────────────────────────────────────────────────────┘
                │
        ┌───────▼────────┐
        │ TriggerHandler │  context, bypass, recursion, orchestration
        └───────┬────────┘
                │
        ┌───────▼────────┐        ┌──────────────┐
        │    Service     │───────▶│    Domain    │  rules, no SOQL/DML
        └───────┬────────┘        └──────────────┘
                │
     ┌──────────┴──────────┐
     │                     │
┌────▼─────┐        ┌──────▼──────┐
│ Selector │        │ UnitOfWork  │
│  (SOQL)  │        │    (DML)    │
└──────────┘        └─────────────┘
```

### Entry points

A trigger file contains one statement:

```apex
trigger AccountTrigger on Account (before insert, before update) {
    TriggerDispatcher.run(new AccountTriggerHandler());
}
```

Nothing else belongs in a trigger. Everything that makes triggers hard to reason about — ordering,
recursion, bypass, error handling — is handled once.

### Trigger handler

`TriggerHandler` resolves the context from `Trigger.isBefore/isAfter` and `isInsert/isUpdate/...`, checks
the bypass layers, guards against recursion and then calls the matching hook. Handlers are
orchestrators: they choose which domain rules or services apply, and in which order. If a handler grows
past twenty lines, the logic is in the wrong place.

`TriggerDispatcher` wraps the call, logs unhandled exceptions with the handler name, and rethrows.
Swallowing would commit a partially applied transaction.

### Domain

A domain holds business rules for one object over a set of records: normalization, invariants,
derived values. It does not query or persist. That constraint is what makes it cheap to test and safe
to reuse from a trigger, a service and a batch job.

Record-level validation uses `addError`/`addFieldError`. In a trigger this becomes a field error on
the record; outside a trigger the record is still marked, so a later DML surfaces the platform error.
Business failures that callers must handle use `AppException` with an error code.

### Service

A service is one transactional use case. It is the only layer allowed to compose access checks,
selectors, domain rules and DML. It is also the API surface for LWC, Aura, Flow and REST, which keeps
the same rules from being reimplemented per entry point.

### Selector

Every SOQL statement lives in a selector. The field list is explicit and declared once, so query cost
is reviewable in a diff. Queries run through `Database.queryWithBinds(..., AccessLevel.USER_MODE)`:
bind variables prevent injection and user mode enforces object/field permissions and sharing.

`selectByQuery` is the escape hatch for predicates the helpers do not cover. It is still a selector
method; it is not an invitation to build SOQL in a service.

### Unit of work

`UnitOfWork` registers new, dirty and deleted records, then commits them in a fixed order: inserts,
updates, deletes. `commitWork` sets a savepoint and rolls the entire unit back if any record fails,
even though individual DML calls use `allOrNone = false`. That gives predictable all-or-nothing
semantics while still producing per-record error messages.

It does not resolve relationships. Parent/child graphs are the caller's responsibility: insert parents
first. Implicit resolution is the feature that makes home-grown units of work impossible to debug.

Access level is user mode by default; `systemMode()` exists for trusted automation and must be
justified in a comment.

### Configuration

`AppConfig` reads `AppConfig__mdt`. Keys are DeveloperNames. Values are parsed into String, Boolean,
Integer, Decimal or a delimited list. Missing keys return the caller's fallback; malformed values
throw a configuration error rather than silently defaulting, because a wrong batch size should fail
during the pull request, not at 2am.

The transaction-level cache means one query per transaction, not per access.

### Security

Three layers, each doing one job:

1. `AccessGuard.requireX` — object-level CRUD checks with explicit error codes.
2. `AccessGuard.stripInaccessible` — removes fields the running user cannot read or write before the
   data is trusted.
3. User-mode SOQL/DML — the platform enforces FLS and sharing on every query and write.

`AccessGuard.requirePermission` wraps custom permissions for opt-in capabilities such as the trigger
bypass.

### Observability

`LogService` buffers `ApplicationLog__c` entries and inserts them in bulk. Entries carry level, source,
message, exception type, line number, stack trace, related record, correlation id and an optional JSON
payload. Inserts run in system mode so telemetry does not depend on the permissions of the user who
triggered the failure, and logging never throws.

See [ADR 0004](adr/0004-record-based-logging.md) for the durability trade-off.

### Async

`QueueableJob`, `BatchJob` and `SchedulableJob` provide the same contract: implement `run`, let the base
class log failures, flush telemetry and apply limits.

- Queueable: rethrows so the platform marks the job failed; `enqueueNext` caps chain depth.
- Batch: a failing scope is logged and does not abort the remaining scopes; batch size comes from
  `AppConfig`.
- Schedulable: logs and rethrows; keep the body to enqueueing real work.

### Testing

- `TestDataFactory` builds and inserts records; tests override only the fields they are about.
- `TestUtils` creates a second user with a unique username, assigns permission sets and asserts DML.
- No test uses `seeAllData=true`. Permission tests use `System.runAs`.
- Framework internals that cannot run outside a trigger (`TriggerRecursionGuard`) are extracted so they
  can be tested directly.

## Sharing model

| Type | Sharing | Reason |
| --- | --- | --- |
| Services, selectors, trigger handlers | `with sharing` | User-facing entry points must respect sharing. |
| UnitOfWork | `inherited sharing` | It must not silently widen access; the caller decides. |
| Domain subclasses | `with sharing` | No queries, but declaring intent keeps reviews honest. |
| Async bases | default (without sharing) | Async work is system automation; call `systemMode()` explicitly where needed. |
| Configuration, logging, guards | default | No business data; logging writes in system mode on purpose. |

## Error strategy

| Situation | Response |
| --- | --- |
| Bad input from a user | `AppException.validation` with field name |
| Missing record the caller expected | `AppException.notFound` with record id |
| Missing permission | `AccessGuard` throws `AppException.security` |
| Bad metadata configuration | `AppException.configuration`, fail fast |
| DML failure | `AppException.dml` with per-record messages |
| Unexpected platform exception | Let it bubble; dispatcher logs and rethrows |

Exception messages are written for the person debugging at 2am: what failed, which record, which field,
and what was expected.

## Extension points

- New object: selector, domain, service, handler, trigger, tests.
- New platform event or callout: a service method plus an async job; never from a trigger body.
- New configuration: add a CMT record; no deployment of code required.
- New permission: custom permission plus a permission set, enforced through `AccessGuard`.
- New async workload: extend the job base; do not implement `Queueable`/`Batchable` directly.

## Trade-offs

| Decision | Cost | Benefit |
| --- | --- | --- |
| Metadata query per trigger transaction | 1 SOQL (cached per transaction) | Disable or bypass without deployment |
| Explicit field lists | Fields added in one more place | Query cost is visible and stable |
| Savepoint-per-commit | Savepoint limit in deeply nested flows | Predictable rollback and error messages |
| No relationship resolution in UoW | Callers order inserts | Debuggable failures |
| Record-based logs | Rolled back with the transaction | Searchable, permissionable, no external dependency |
