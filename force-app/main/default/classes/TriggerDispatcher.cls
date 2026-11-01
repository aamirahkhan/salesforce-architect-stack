/**
 * Single entry point used by trigger files.
 *
 * Keeps trigger files to one line, logs unhandled failures with the handler and record context,
 * and rethrows so the platform still rolls back the transaction. The rethrow is deliberate:
 * swallowing a trigger error would commit partially applied business rules.
 */
public class TriggerDispatcher {
    private TriggerDispatcher() {
    }

    public static void run(TriggerHandler handler) {
        if (handler == null) {
            throw AppException.configuration('A trigger handler is required.');
        }

        try {
            handler.run();
        } catch (Exception problem) {
            LogService.error(
                'TriggerDispatcher',
                'Unhandled exception in ' + handler.getHandlerName() + ': ' + problem.getMessage(),
                problem
            );
            LogService.flush();
            throw problem;
        }
    }
}
