/**
 * Base class for domain logic over a set of records.
 *
 * A domain owns business rules for one object: normalizing values, validating invariants and
 * deriving fields. It performs no SOQL and no DML, which makes it the cheapest layer to unit test
 * and the safest place to put rules that several entry points share (trigger, service, async job).
 *
 * Validation methods call addError/addFieldError. In a trigger context those surface as field
 * errors on the record; outside a trigger they still mark the in-memory record, so callers that
 * persist records afterwards get a platform DmlException listing them.
 */
public abstract class SObjectDomain {
    private List<SObject> records;

    protected SObjectDomain(List<SObject> records) {
        if (records == null) {
            throw AppException.configuration('A domain requires a record collection.');
        }
        this.records = records;
    }

    public List<SObject> getRecords() {
        return records;
    }

    public Integer size() {
        return records.size();
    }

    public Boolean isEmpty() {
        return records.isEmpty();
    }

    public Set<Id> getRecordIds() {
        Set<Id> recordIds = new Set<Id>();
        for (SObject record : records) {
            if (record.Id != null) {
                recordIds.add(record.Id);
            }
        }
        return recordIds;
    }

    protected void addError(SObject record, String message) {
        record.addError(message);
    }

    protected void addFieldError(SObject record, SObjectField field, String message) {
        record.addError(field, message);
    }

    protected void requireId(SObject record, String operation) {
        if (record.Id == null) {
            throw AppException.configuration(operation + ' requires a persisted record.');
        }
    }
}
