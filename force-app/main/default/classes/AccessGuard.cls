/**
 * Single place where object permissions, field permissions and custom permissions are enforced.
 *
 * Services call requireUpdateable() before writing and stripInaccessible() before trusting
 * fields supplied from a client. Data access runs in user mode by default (see SObjectSelector
 * and UnitOfWork), so this class exists to produce a clear error before the platform produces
 * a cryptic INSUFFICIENT_ACCESS exception.
 */
public class AccessGuard {
    private AccessGuard() {
    }

    public static Boolean hasPermission(String customPermissionApiName) {
        if (String.isBlank(customPermissionApiName)) {
            return false;
        }
        return FeatureManagement.checkPermission(customPermissionApiName);
    }

    public static void requirePermission(String customPermissionApiName) {
        if (!hasPermission(customPermissionApiName)) {
            throw AppException.security('Missing custom permission: ' + customPermissionApiName);
        }
    }

    public static void requireReadable(SObjectType sObjectType) {
        requireObjectAccess(sObjectType, AccessType.READABLE);
    }

    public static void requireCreateable(SObjectType sObjectType) {
        requireObjectAccess(sObjectType, AccessType.CREATABLE);
    }

    public static void requireUpdateable(SObjectType sObjectType) {
        requireObjectAccess(sObjectType, AccessType.UPDATABLE);
    }

    public static void requireDeletable(SObjectType sObjectType) {
        if (sObjectType == null) {
            throw AppException.configuration('An SObject type is required.');
        }
        Schema.DescribeSObjectResult describe = sObjectType.getDescribe();
        if (!describe.isDeletable()) {
            throw AppException.security('Insufficient DELETE access to ' + describe.getName());
        }
    }

    /**
     * Removes fields the running user cannot read or write.
     * Pass failOnRemoval = true when a silently dropped field would change the outcome.
     */
    public static List<SObject> stripInaccessible(List<SObject> records, AccessType accessType, Boolean failOnRemoval) {
        if (records == null || records.isEmpty()) {
            return new List<SObject>();
        }

        SObjectAccessDecision decision = Security.stripInaccessible(accessType, records);
        if (failOnRemoval) {
            Map<String, Set<String>> removedFields = decision.getRemovedFields();
            if (!removedFields.isEmpty()) {
                throw AppException.security(
                    'Fields removed for the running user: ' + String.valueOf(removedFields.keySet())
                );
            }
        }
        return decision.getRecords();
    }

    public static SObject stripInaccessible(SObject record, AccessType accessType) {
        if (record == null) {
            return null;
        }
        List<SObject> stripped = stripInaccessible(new List<SObject>{ record }, accessType, false);
        return stripped.isEmpty() ? null : stripped[0];
    }

    private static void requireObjectAccess(SObjectType sObjectType, AccessType requiredAccess) {
        if (sObjectType == null) {
            throw AppException.configuration('An SObject type is required.');
        }

        Schema.DescribeSObjectResult describe = sObjectType.getDescribe();
        Boolean allowed;
        if (requiredAccess == AccessType.READABLE) {
            allowed = describe.isAccessible();
        } else if (requiredAccess == AccessType.CREATABLE) {
            allowed = describe.isCreateable();
        } else if (requiredAccess == AccessType.UPDATABLE) {
            allowed = describe.isUpdateable();
        } else if (requiredAccess == AccessType.UPSERTABLE) {
            allowed = describe.isCreateable() || describe.isUpdateable();
        } else {
            allowed = false;
        }

        if (!allowed) {
            throw AppException.security('Insufficient ' + requiredAccess.name() + ' access to ' + describe.getName());
        }
    }
}
