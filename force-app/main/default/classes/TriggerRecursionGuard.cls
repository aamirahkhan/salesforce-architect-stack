/**
 * Tracks which records a named handler has already processed in the current transaction.
 *
 * Extracted from TriggerHandler so the semantics can be unit tested without a DML context.
 * A handler is skipped when every record in the current context has already been handled for that
 * handler name. Handlers mark records before executing, so re-entrant DML from an after-trigger
 * does not loop.
 */
public class TriggerRecursionGuard {
    private static final Map<String, Set<Id>> HANDLED_IDS_BY_SCOPE = new Map<String, Set<Id>>();

    private TriggerRecursionGuard() {
    }

    public static Boolean isHandled(String scope, Set<Id> recordIds) {
        if (String.isBlank(scope) || recordIds == null || recordIds.isEmpty()) {
            return false;
        }

        Set<Id> handledIds = HANDLED_IDS_BY_SCOPE.get(scope);
        if (handledIds == null) {
            return false;
        }
        for (Id recordId : recordIds) {
            if (!handledIds.contains(recordId)) {
                return false;
            }
        }
        return true;
    }

    public static void markHandled(String scope, Set<Id> recordIds) {
        if (String.isBlank(scope) || recordIds == null || recordIds.isEmpty()) {
            return;
        }

        Set<Id> handledIds = HANDLED_IDS_BY_SCOPE.get(scope);
        if (handledIds == null) {
            handledIds = new Set<Id>();
            HANDLED_IDS_BY_SCOPE.put(scope, handledIds);
        }
        for (Id recordId : recordIds) {
            handledIds.add(recordId);
        }
    }

    @TestVisible
    private static void resetAll() {
        HANDLED_IDS_BY_SCOPE.clear();
    }
}
