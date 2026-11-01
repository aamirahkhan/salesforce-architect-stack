/**
 * Base class for all trigger handlers.
 *
 * A trigger file contains a single line that hands the handler to TriggerDispatcher. The handler
 * declares which object it serves and overrides only the contexts it cares about. Everything else
 * — context detection, bypass checks, recursion control and error logging — lives here.
 *
 * Recursion control is per handler and per transaction: a record is marked as handled before the
 * handler body runs, so an update inside an after-update handler does not re-enter the same handler
 * for the same records. This is deliberate. If a handler genuinely needs to reprocess a record in
 * the same transaction, perform that work explicitly rather than re-entering the trigger.
 */
public abstract class TriggerHandler {
    public enum TriggerContext {
        BEFORE_INSERT,
        BEFORE_UPDATE,
        BEFORE_DELETE,
        AFTER_INSERT,
        AFTER_UPDATE,
        AFTER_DELETE,
        AFTER_UNDELETE
    }

    private TriggerContext context;
    private String handlerName;

    public abstract SObjectType getSObjectType();

    protected virtual void beforeInsert() {
    }

    protected virtual void beforeUpdate() {
    }

    protected virtual void beforeDelete() {
    }

    protected virtual void afterInsert() {
    }

    protected virtual void afterUpdate() {
    }

    protected virtual void afterDelete() {
    }

    protected virtual void afterUndelete() {
    }

    public void run() {
        if (TriggerControl.isBypassed(getHandlerName())) {
            return;
        }

        // Trigger context flags are null outside a trigger, so check the flag that is safe to read
        // everywhere before resolveContext() dereferences them.
        if (!Trigger.isExecuting) {
            throw AppException.configuration(
                'TriggerHandler ' + getHandlerName() + ' can only run inside a trigger context.'
            );
        }

        context = resolveContext();
        if (context == null) {
            throw AppException.configuration(
                'TriggerHandler ' + getHandlerName() + ' can only run inside a trigger context.'
            );
        }

        assertSObjectType();

        if (wasHandled()) {
            return;
        }
        markHandled();

        execute();
    }

    public String getHandlerName() {
        if (handlerName == null) {
            String description = String.valueOf(this);
            handlerName = description.substringBefore(':');
            if (String.isBlank(handlerName)) {
                handlerName = description;
            }
        }
        return handlerName;
    }

    public TriggerContext getTriggerContext() {
        return context;
    }

    protected List<SObject> getNewRecords() {
        return Trigger.new == null ? new List<SObject>() : Trigger.new;
    }

    protected List<SObject> getOldRecords() {
        return Trigger.old == null ? new List<SObject>() : Trigger.old;
    }

    public static void bypass(String handlerName) {
        TriggerControl.bypass(handlerName);
    }

    public static void clearBypass(String handlerName) {
        TriggerControl.clearBypass(handlerName);
    }

    public static void clearAllBypasses() {
        TriggerControl.clearAllBypasses();
    }

    public static Boolean isBypassed(String handlerName) {
        return TriggerControl.isBypassed(handlerName);
    }

    private void execute() {
        switch on context {
            when BEFORE_INSERT {
                beforeInsert();
            }
            when BEFORE_UPDATE {
                beforeUpdate();
            }
            when BEFORE_DELETE {
                beforeDelete();
            }
            when AFTER_INSERT {
                afterInsert();
            }
            when AFTER_UPDATE {
                afterUpdate();
            }
            when AFTER_DELETE {
                afterDelete();
            }
            when AFTER_UNDELETE {
                afterUndelete();
            }
        }
    }

    private void assertSObjectType() {
        List<SObject> records = context == TriggerContext.BEFORE_DELETE || context == TriggerContext.AFTER_DELETE
            ? getOldRecords()
            : getNewRecords();
        if (records.isEmpty()) {
            return;
        }

        SObjectType actualType = records[0].getSObjectType();
        if (actualType != getSObjectType()) {
            throw AppException.configuration(
                getHandlerName() +
                ' is registered for ' +
                getSObjectType().getDescribe().getName() +
                ' but ran on ' +
                actualType.getDescribe().getName() +
                '.'
            );
        }
    }

    private Boolean wasHandled() {
        return TriggerRecursionGuard.isHandled(getHandlerName(), currentRecordIds());
    }

    private void markHandled() {
        TriggerRecursionGuard.markHandled(getHandlerName(), currentRecordIds());
    }

    private Set<Id> currentRecordIds() {
        Set<Id> recordIds = new Set<Id>();
        List<SObject> records = context == TriggerContext.BEFORE_DELETE || context == TriggerContext.AFTER_DELETE
            ? getOldRecords()
            : getNewRecords();
        for (SObject record : records) {
            if (record.Id != null) {
                recordIds.add(record.Id);
            }
        }
        return recordIds;
    }

    private TriggerContext resolveContext() {
        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                return TriggerContext.BEFORE_INSERT;
            }
            if (Trigger.isUpdate) {
                return TriggerContext.BEFORE_UPDATE;
            }
            if (Trigger.isDelete) {
                return TriggerContext.BEFORE_DELETE;
            }
        } else if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                return TriggerContext.AFTER_INSERT;
            }
            if (Trigger.isUpdate) {
                return TriggerContext.AFTER_UPDATE;
            }
            if (Trigger.isDelete) {
                return TriggerContext.AFTER_DELETE;
            }
            if (Trigger.isUndelete) {
                return TriggerContext.AFTER_UNDELETE;
            }
        }
        return null;
    }
}
