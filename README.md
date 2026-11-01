# Salesforce Architect Stack

A deployable reference architecture for Salesforce teams who are tired of rebuilding the same
trigger framework on every project — and of the security, recursion and logging bugs that come with
each hand-rolled version.

This is a working baseline, not a presentation: 21 production Apex classes, 10 test classes, 1
trigger, custom metadata configuration, a permission set, and CI that verifies the source before
anything reaches an org.

![CI](https://github.com/aamirahkhan/salesforce-architect-stack/actions/workflows/ci.yml/badge.svg)

## What is in the stack

| Layer | Class | Responsibility |
| --- | --- | --- |
| Entry | `AccountTrigger` | One line. No logic, ever. |
| Dispatch | `TriggerDispatcher` | Runs the handler, logs unhandled failures, rethrows. |
| Trigger control | `TriggerHandler`, `TriggerControl`, `TriggerRecursionGuard` | Context detection, bypass, metadata enablement, recursion guard. |
| Domain | `SObjectDomain`, `AccountDomain` | Business rules over records. No SOQL, no DML. |
| Service | `AccountService` | Transactional use cases; composes access checks, queries, rules and DML. |
| Data access | `SObjectSelector`, `AccountSelector` | Every SOQL query, with an explicit field list and user-mode enforcement. |
| Persistence | `UnitOfWork` | Atomic inserts, updates and deletes with savepoint rollback. |
| Configuration | `AppConfig` | Typed, deployable settings from `AppConfig__mdt`. |
| Security | `AccessGuard` | CRUD/FLS checks, `stripInaccessible`, custom permissions. |
| Observability | `LogService`, `ApplicationLog__c` | Buffered logs with exception type, line, stack trace and payload. |
| Async | `QueueableJob`, `BatchJob`, `SchedulableJob` | Job bases with logging, batch sizing and chaining guards. |
| Errors | `AppException`, `ExceptionUtils` | Structured error codes, record/field context, null-safe introspection. |
| Testing | `TestDataFactory`, `TestUtils` | Builders, inserts, second-user creation, DML assertions. |

API version: **68.0** (Winter '27).

## Quickstart

```bash
npm ci

sf org login web --alias devhub --set-default-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --alias stack --set-default
sf project deploy start --source-dir force-app --wait 30
sf org assign permset --name Architect_Stack_Admin
sf apex run test --test-level RunLocalTests --code-coverage --wait 30
sf org open
```

The repo also deploys to a sandbox or production org with `sf project deploy start`.

## Request flow

```
AccountTrigger (1 line)
  └── TriggerDispatcher.run(new AccountTriggerHandler())
        └── TriggerHandler.run()
              ├── TriggerControl.isBypassed()      metadata + permission + runtime
              ├── TriggerRecursionGuard            per handler, per transaction
              └── AccountTriggerHandler.beforeInsert()
                    └── AccountDomain                normalize, validate
                    └── AccountService               (for transactional use cases)
                          ├── AccessGuard            CRUD/FLS and error codes
                          ├── AccountSelector        SOQL, user mode, explicit fields
                          ├── UnitOfWork             DML, atomic, savepoint
                          └── LogService             buffered telemetry
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the reasoning behind each boundary and
[docs/CODING-STANDARDS.md](docs/CODING-STANDARDS.md) for the rules the team is expected to follow.

## Add a feature in five steps

1. **Selector** — create `InvoiceSelector extends SObjectSelector`, declare its fields and query
   methods. No SOQL anywhere else.
2. **Domain** — create `InvoiceDomain extends SObjectDomain` for validation and normalization. No
   SOQL or DML.
3. **Service** — create `InvoiceService` with one method per use case. Enforce access, query through
   the selector, persist through the unit of work.
4. **Trigger** — create `InvoiceTriggerHandler extends TriggerHandler` and a one-line
   `InvoiceTrigger`. A trigger handler orchestrates, it does not decide business rules.
5. **Tests** — one test class per unit. Use `TestDataFactory`; never `seeAllData=true`.

## Configuration

`AppConfig__mdt` records (DeveloperName is the key):

| Record | Value | Used by |
| --- | --- | --- |
| `AllowedBillingCountries` | `US,CA,GB` | `AccountDomain.validateBillingCountry` |
| `DefaultBatchSize` | `200` | `BatchJob.getBatchSize` |
| `Enable_Strict_Validation` | `true` | Available to feature flags via `AppConfig.getBoolean` |

`TriggerSetting__mdt` records disable a handler (`Is_Active__c`) or require a custom permission
(`Bypass_Custom_Permission__c`) without a deployment. `AccountTriggerHandler` is wired to
`Bypass_Trigger_Framework`.

## Verification

```bash
npm run verify        # Apex syntax, XML/JSON validity, metadata pairing, framework references
npm run format        # Prettier + prettier-plugin-apex (requires Java 11+)
```

CI runs `npm run verify` on every push and pull request, plus a weekly cron so the baseline does not
silently drift from the current release. A second job creates a scratch org, deploys the source and
runs `RunLocalTests` when the `SFDX_AUTH_URL` secret is configured. Create it with:

```bash
sf org display --target-org devhub --verbose --json | jq -r '.result.sfdxAuthUrl'
```

Paste the output into the repository secret `SFDX_AUTH_URL`. Never commit it.

## Deliberate limitations

- `UnitOfWork` does not resolve parent/child relationships. Insert parents, then register children
  with their Ids. This keeps failure reporting and ordering understandable.
- Logs written in a transaction that later rolls back are rolled back too. Use an external sink for
  audit-grade durability; see [ADR 0004](docs/adr/0004-record-based-logging.md).
- The recursion guard marks records before the handler body runs, so an after-trigger cannot use DML
  to re-enter the same handler for the same records in the same transaction.
- The guard is per handler, not per record branch. If a handler must reprocess a record, do it
  explicitly inside the handler rather than re-entering the trigger.
- No LWC, Aura or Flow layer is included. `AccountService.updateRating` is `@AuraEnabled` to show
  where that boundary belongs.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Coding standards](docs/CODING-STANDARDS.md)
- [ADR 0001 — layered Apex architecture](docs/adr/0001-layered-apex-architecture.md)
- [ADR 0002 — metadata-driven trigger control](docs/adr/0002-metadata-driven-trigger-control.md)
- [ADR 0003 — user-mode data access by default](docs/adr/0003-user-mode-data-access.md)
- [ADR 0004 — record-based logging](docs/adr/0004-record-based-logging.md)
- [Contributing](CONTRIBUTING.md)
