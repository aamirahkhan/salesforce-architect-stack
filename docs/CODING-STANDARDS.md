# Coding standards

These are review criteria, not preferences. A pull request that breaks them should say why in the
description.

## Naming

| Thing | Convention | Example |
| --- | --- | --- |
| Trigger handler | `<Object>TriggerHandler` | `AccountTriggerHandler` |
| Domain | `<Object>Domain` | `AccountDomain` |
| Selector | `<Object>Selector` | `AccountSelector` |
| Service | `<Object>Service` or `<Capability>Service` | `AccountService` |
| Batch / queueable / schedulable | `<Purpose>BatchJob`, `<Purpose>QueueableJob` | `InvoiceSyncBatchJob` |
| Test class | `<ClassUnderTest>_TEST` | `UnitOfWork_TEST` |
| Custom object | Singular noun | `ApplicationLog__c` |
| Custom metadata type | Singular noun | `AppConfig__mdt` |
| Custom metadata record | PascalCase key | `AllowedBillingCountries` |
| Custom permission | Verb phrase | `Bypass_Trigger_Framework` |

## Apex style

- 4 spaces, 120 column limit, one statement per line.
- Guard clauses over nested `if`s. Return early.
- Declare variables at the smallest scope that works.
- Prefer `String.isBlank(value)` over `value == null || value.trim() == ''`.
- Never compare Booleans to `true`/`false`; use the value, except for nullable checkboxes where the
  comparison is the point (`setting.Is_Active__c != true`).
- Use `Assert` methods, not `System.assert`.
- Use `@TestVisible` for seams, not for widening production API.

## SOQL

- All SOQL lives in a selector. No exceptions, including "one quick query" in a service.
- Declare the field list explicitly. `SELECT *` does not exist; a describe-driven field list does and
  it hides cost.
- Bind every value. Never concatenate user input or record data into a query string.
- Queries run in user mode by default. If a query must run in system mode, it needs a comment saying
  which authorization check replaced the platform's.
- No SOQL inside loops. Collect ids, query once, map the results.
- `LIMIT` any query that is not bounded by a filter the caller controls.

## DML

- Services persist through `UnitOfWork`. Direct DML is allowed only in tests, migrations and scripts,
  and must be justified.
- Set `allOrNone = false` only when partial success is a real requirement; otherwise let the platform
  fail the whole transaction.
- Never DML inside a loop.
- Savepoints are a limited resource. Do not nest units of work without understanding the limit.
- `systemMode()` requires a comment naming the authorization check that already happened.

## Triggers

- One trigger per object, delegating to one handler in one line.
- A handler contains orchestration only. Business rules go to a domain or service.
- Never query or DML in a trigger body or a handler when a service can own the operation.
- Never bypass the framework with `TriggerHandler.bypass` in production code. The custom permission is
  the supported bypass for integration users; runtime bypass is for tests and controlled scripts.
- Do not assume trigger order. If two handlers must run in order, combine them or make the dependency
  explicit inside one handler.

## Errors

- Throw `AppException` for expected business failures, with the narrowest error code that fits.
- Include the record id, field name and the expected shape of the data in the message.
- Do not catch an exception you cannot handle. Logging it and continuing is not handling it.
- Never catch `Exception` and return `null`. Callers cannot distinguish "no data" from "failed".
- Do not expose stack traces or raw platform messages to users through `@AuraEnabled` methods.

## Security

- Enforce object access before a user-facing write (`AccessGuard.requireUpdateable`).
- Strip inaccessible fields before trusting client-supplied records.
- Check custom permissions for opt-in capabilities, not profile names.
- Never hardcode record ids, org ids or user ids. Resolve them from configuration or metadata.
- Never put secrets in Apex, custom metadata, custom settings or custom labels.

## Tests

- No `seeAllData=true`.
- Build data with `TestDataFactory`; override only the fields the test is about.
- One behaviour per test method, named for the behaviour, not the method under test.
- Assert messages must explain the expected behaviour, not repeat the assertion.
- Test the failure path as seriously as the happy path.
- Permission and sharing behaviour needs a second user via `System.runAs`.
- Tests must pass in a fresh scratch org. If a test depends on org data, it is not a test.
- Target 90%+ coverage of framework classes. Coverage is a floor, not the goal.

## Documentation

- Public framework classes have a docblock explaining the responsibility and the non-obvious trade-off.
- Comments explain why, not what. `// increment i` is noise.
- Every architectural decision that a reasonable engineer might reverse gets an ADR in `docs/adr/`.
- Update the README when a quickstart step, configuration key or layer changes.

## Review checklist

- [ ] Logic is in the correct layer
- [ ] No SOQL or DML outside selector / unit of work
- [ ] Access enforced for user-reachable code
- [ ] Errors carry code, record and field context
- [ ] Tests cover success and failure
- [ ] No secrets or org-specific ids
- [ ] `npm run verify` passes
