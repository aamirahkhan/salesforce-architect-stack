/**
 * Base class for batch work.
 *
 * Subclasses supply the query and the per-scope unit of work. A failing scope is logged and does not
 * abort the remaining scopes, because a single malformed record should not strand a million-record
 * backfill. Use the finish hook for post-processing and let the base class flush logs.
 */
public abstract class BatchJob implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        String query = getQuery();
        if (String.isBlank(query)) {
            throw AppException.configuration(getJobName() + ': a batch query is required.');
        }
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        try {
            run(context, scope);
        } catch (Exception problem) {
            LogService.error(getJobName(), 'Batch scope failed: ' + problem.getMessage(), problem);
        }
    }

    public void finish(Database.BatchableContext context) {
        try {
            onFinish(context);
        } catch (Exception problem) {
            LogService.error(getJobName(), 'Batch finish failed: ' + problem.getMessage(), problem);
        }
        LogService.flush();
    }

    public abstract String getQuery();

    public abstract void run(Database.BatchableContext context, List<SObject> scope);

    protected virtual void onFinish(Database.BatchableContext context) {
    }

    public Integer getBatchSize() {
        return AppConfig.getInteger('DefaultBatchSize', 200);
    }

    public Id submit() {
        return Database.executeBatch(this, getBatchSize());
    }

    public String getJobName() {
        String description = String.valueOf(this);
        String name = description.substringBefore(':');
        return String.isBlank(name) ? description : name;
    }
}
