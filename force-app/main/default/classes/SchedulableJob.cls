/**
 * Base class for scheduled entry points.
 *
 * A scheduled class should do one thing: enqueue the real work (batch or queueable) and return.
 * Keeping the body short avoids the most common scheduled-job failure, a Schedulable implementation
 * that quietly exceeds its own query or DML limits.
 */
public abstract class SchedulableJob implements Schedulable {
    public void execute(SchedulableContext context) {
        try {
            run(context);
        } catch (Exception problem) {
            LogService.error(getJobName(), 'Scheduled job failed: ' + problem.getMessage(), problem);
            throw problem;
        } finally {
            LogService.flush();
        }
    }

    public abstract void run(SchedulableContext context);

    public String getJobName() {
        String description = String.valueOf(this);
        String name = description.substringBefore(':');
        return String.isBlank(name) ? description : name;
    }
}
