# ADR 0003 — User-mode data access by default

- **Status:** Accepted
- **Date:** 2026-11-01
- **Deciders:** Salesforce architecture

## Context

Apex runs in system mode by default. That means a query in a service can return records the running
user cannot see, and a write can modify fields the user cannot edit. `WITH SECURITY_ENFORCED` catches
some field-level problems in SOQL but not object permissions, not CRUD on DML, and it fails the whole
query rather than filtering.

Security reviews therefore become a manual audit of every query and every DML statement. That audit
does not scale, and it fails silently the first time someone adds a new field to a query.

## Decision

Use user mode by default at the data boundary:

- Selectors call `Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)`.
- `UnitOfWork` calls `Database.insert/update/delete(records, false, AccessLevel.USER_MODE)`.
- Services call `AccessGuard.requireX` to produce a clear, coded error before the platform produces a
  generic `INSUFFICIENT_ACCESS` exception.
- `AccessGuard.stripInaccessible` removes fields the running user cannot read or write before payloads
  are trusted.

System mode is available but explicit:

```apex
new UnitOfWork().systemMode() // trusted automation; authorization already performed
```

Every `systemMode()` call must have a neighbouring comment explaining which check replaced the
platform's enforcement.

## Consequences

**Positive**

- Sharing, object permissions and field permissions are enforced by the platform, not by code review.
- Permission bugs surface in tests with a second user, before deployment.
- The security review question changes from "did you remember FLS here?" to "where is system mode
  used, and why?"
- `stripInaccessible` makes partial access a supported outcome rather than an exception.

**Negative**

- Integration users need the right permissions. A background job running as a low-privilege user fails
  until permissions are granted, which is correct but requires setup.
- User-mode queries are subject to sharing rules, so a service that ran as system mode in a legacy org
  may return fewer rows after migration.
- `stripInaccessible` adds a describe cost per call. Keep it at entry points, not inside loops.
- Tests must create users and permission sets to cover the denial path.

## Alternatives considered

**Leave system mode, enforce manually.** Fast to write, impossible to verify consistently.

**`WITH SECURITY_ENFORCED` everywhere.** Covers field-level SOQL only, throws instead of filtering, and
does nothing for DML or object permissions.

**`Security.stripInaccessible` only.** Filters fields but does not enforce object-level access or
sharing on queries.

## References

- [Salesforce: Enforce permissions in Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_chapter.htm)
- `AccessGuard`, `SObjectSelector`, `UnitOfWork`
