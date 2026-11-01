/**
 * Collects records and commits them as one atomic transaction.
 *
 * Ordering inside commitWork is inserts, updates, deletes. Parent/child relationships are not
 * resolved automatically: insert parents, then register children that reference the resulting Ids.
 * That limitation is intentional — implicit relationship resolution is where most home-grown
 * unit-of-work implementations become impossible to debug.
 *
 * Atomicity: commitWork sets a savepoint and rolls the whole unit back when any record fails, even
 * though the individual DML calls use allOrNone = false. Use Database directly when partial success
 * is genuinely required.
 *
 * Access: user mode by default. Call systemMode() only in trusted automation that has already
 * performed its own authorization, and say why in a comment.
 */
public inherited sharing class UnitOfWork {
    private List<SObject> newRecords = new List<SObject>();
    private List<SObject> dirtyRecords = new List<SObject>();
    private List<SObject> deletedRecords = new List<SObject>();

    private AccessLevel accessLevel = AccessLevel.USER_MODE;

    public UnitOfWork userMode() {
        accessLevel = AccessLevel.USER_MODE;
        return this;
    }

    public UnitOfWork systemMode() {
        accessLevel = AccessLevel.SYSTEM_MODE;
        return this;
    }

    public UnitOfWork registerNew(SObject record) {
        if (record == null) {
            throw AppException.configuration('Cannot register a null record for insert.');
        }
        newRecords.add(record);
        return this;
    }

    public UnitOfWork registerNew(List<SObject> records) {
        if (records != null) {
            for (SObject record : records) {
                registerNew(record);
            }
        }
        return this;
    }

    public UnitOfWork registerDirty(SObject record) {
        if (record == null) {
            throw AppException.configuration('Cannot register a null record for update.');
        }
        if (record.Id == null) {
            throw AppException.configuration('registerDirty requires a record with an Id. Use registerNew instead.');
        }
        dirtyRecords.add(record);
        return this;
    }

    public UnitOfWork registerDirty(List<SObject> records) {
        if (records != null) {
            for (SObject record : records) {
                registerDirty(record);
            }
        }
        return this;
    }

    public UnitOfWork registerDeleted(SObject record) {
        if (record == null) {
            throw AppException.configuration('Cannot register a null record for delete.');
        }
        if (record.Id == null) {
            throw AppException.configuration('registerDeleted requires a record with an Id.');
        }
        deletedRecords.add(record);
        return this;
    }

    public UnitOfWork registerDeleted(List<SObject> records) {
        if (records != null) {
            for (SObject record : records) {
                registerDeleted(record);
            }
        }
        return this;
    }

    public Integer size() {
        return newRecords.size() + dirtyRecords.size() + deletedRecords.size();
    }

    public Boolean isEmpty() {
        return size() == 0;
    }

    public void commitWork() {
        if (isEmpty()) {
            return;
        }

        Savepoint checkpoint = Database.setSavepoint();
        try {
            insertNewRecords();
            updateDirtyRecords();
            deleteRecords();
        } catch (AppException problem) {
            Database.rollback(checkpoint);
            throw problem;
        } catch (Exception problem) {
            Database.rollback(checkpoint);
            throw AppException.dml('Unit of work failed: ' + ExceptionUtils.describe(problem));
        }
    }

    private void insertNewRecords() {
        if (newRecords.isEmpty()) {
            return;
        }
        List<Database.SaveResult> results = Database.insert(newRecords, false, accessLevel);
        assertSaveResults(results, newRecords, 'Insert');
    }

    private void updateDirtyRecords() {
        if (dirtyRecords.isEmpty()) {
            return;
        }
        List<Database.SaveResult> results = Database.update(dirtyRecords, false, accessLevel);
        assertSaveResults(results, dirtyRecords, 'Update');
    }

    private void deleteRecords() {
        if (deletedRecords.isEmpty()) {
            return;
        }
        List<Database.DeleteResult> results = Database.delete(deletedRecords, false, accessLevel);
        List<String> failures = new List<String>();
        for (Integer index = 0; index < results.size(); index++) {
            if (results[index].isSuccess()) {
                continue;
            }
            for (Database.Error error : results[index].getErrors()) {
                failures.add(String.valueOf(deletedRecords[index].Id) + ': ' + error.getMessage());
            }
        }
        if (!failures.isEmpty()) {
            throw AppException.dml('Delete failed: ' + String.join(failures, ' '));
        }
    }

    private void assertSaveResults(List<Database.SaveResult> results, List<SObject> records, String operation) {
        List<String> failures = new List<String>();
        for (Integer index = 0; index < results.size(); index++) {
            if (results[index].isSuccess()) {
                continue;
            }
            String recordReference = records[index].Id == null
                ? 'Row ' + String.valueOf(index + 1)
                : String.valueOf(records[index].Id);
            for (Database.Error error : results[index].getErrors()) {
                failures.add(recordReference + ': ' + error.getMessage());
            }
        }
        if (!failures.isEmpty()) {
            throw AppException.dml(operation + ' failed: ' + String.join(failures, ' '));
        }
    }
}
