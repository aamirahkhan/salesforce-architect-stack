/**
 * Base class for queueable work.
 *
 * Subclasses implement run(). The base class logs unhandled failures and rethrows so the platform
 * marks the job failed, and guards chained jobs against runaway depth. Chaining is capped rather
 * than unbounded because a self-chaining queueable is the most common way to exhaust org limits
 * silently overnight.
 */
public abstract class QueueableJob implements Queueable {
    public static final Integer MAX_CHAIN_DEPTH = 10;

    private Integer chainDepth = 0;

    public void execute(QueueableContext context) {
        try {
            run(context);
        } catch (Exception problem) {
            LogService.error(getJobName(), 'Queueable job failed: ' + problem.getMessage(), problem);
            LogService.flush();
            throw problem;
        }
    }

    public abstract void run(QueueableContext context);

    protected Id enqueueNext(QueueableJob nextJob) {
        if (nextJob == null) {
            throw AppException.configuration('A queueable job is required to chain.');
        }
        if (chainDepth >= MAX_CHAIN_DEPTH) {
            LogService.warn(
                getJobName(),
                'Maximum queueable chain depth (' + MAX_CHAIN_DEPTH + ') reached. The next job was not enqueued.'
            );
            return null;
        }
        nextJob.chainDepth = chainDepth + 1;
        return System.enqueueJob(nextJob);
    }

    public String getJobName() {
        String description = String.valueOf(this);
        String name = description.substringBefore(':');
        return String.isBlank(name) ? description : name;
    }
}
