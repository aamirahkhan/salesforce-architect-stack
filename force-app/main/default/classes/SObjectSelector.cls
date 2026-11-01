/**
 * Base class for every SOQL query in the application.
 *
 * Queries are assembled from the field list each selector declares, so a selector cannot
 * accidentally drift from the fields its callers expect, and every query runs in user mode by
 * default (FLS and sharing are enforced). Selectors return SObjects; mapping to typed lists is
 * the subclass's job, which keeps the generic machinery in one place.
 *
 * Binding: queryWhere() takes a bind map keyed by the token used in the WHERE clause, e.g.
 * queryWhere('Id IN :recordIds', new Map<String, Object>{ 'recordIds' => ids }).
 */
public abstract class SObjectSelector {
    public abstract SObjectType getSObjectType();

    protected abstract List<SObjectField> getFields();

    protected virtual List<String> getOrderBy() {
        return new List<String>{ 'Id' };
    }

    protected String getObjectName() {
        return getSObjectType().getDescribe().getName();
    }

    public List<SObject> selectById(Set<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) {
            return new List<SObject>();
        }
        return queryWhere(
            'Id IN :recordIds',
            new Map<String, Object>{ 'recordIds' => new List<Id>(recordIds) }
        );
    }

    public List<SObject> selectByField(SObjectField filterField, Set<Object> values) {
        if (filterField == null || values == null || values.isEmpty()) {
            return new List<SObject>();
        }
        return queryWhere(
            filterField.getDescribe().getName() + ' IN :values',
            new Map<String, Object>{ 'values' => new List<Object>(values) }
        );
    }

    /**
     * Escape hatch for predicates the helpers do not cover. Keep the SOQL in the selector layer
     * and always bind values rather than concatenating them.
     */
    public List<SObject> selectByQuery(String whereClause, Map<String, Object> bindMap) {
        return queryWhere(whereClause, bindMap);
    }

    protected List<SObject> queryWhere(String whereClause, Map<String, Object> bindMap) {
        String soql = 'SELECT ' + String.join(getFieldNames(), ', ') + ' FROM ' + getObjectName();
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }

        List<String> orderBy = getOrderBy();
        if (orderBy != null && !orderBy.isEmpty()) {
            soql += ' ORDER BY ' + String.join(orderBy, ', ');
        }

        Map<String, Object> binds = bindMap == null ? new Map<String, Object>() : bindMap;
        return Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    private List<String> getFieldNames() {
        List<SObjectField> fields = getFields();
        if (fields == null || fields.isEmpty()) {
            throw AppException.configuration(
                getObjectName() + ' selector must declare at least one field to query.'
            );
        }

        List<String> names = new List<String>();
        for (SObjectField field : fields) {
            names.add(field.getDescribe().getName());
        }
        return names;
    }
}
