/**
 * Application logging to ApplicationLog__c.
 *
 * Entries are buffered and inserted in bulk on flush() to stay inside DML limits. Inserts run
 * in system mode on purpose: observability must not depend on the permissions of the user who
 * happened to trigger the failure. Logging never throws; a failure to persist a log entry is
 * written to the debug log instead of breaking the caller's transaction.
 *
 * Rolling back the surrounding transaction also rolls back its logs. Use an external sink
 * (see docs/adr/0004-record-based-logging.md) when logs must survive a failed transaction.
 */
public class LogService {
    public enum Level {
        ERROR,
        WARN,
        INFO,
        DEBUG
    }

    private static final Integer MAX_BUFFER_SIZE = 200;
    private static final Integer MESSAGE_LIMIT = 32768;
    private static final Integer STACK_TRACE_LIMIT = 131072;

    private static final List<ApplicationLog__c> BUFFER = new List<ApplicationLog__c>();

    private LogService() {
    }

    public static void error(String source, String message) {
        enqueue(Level.ERROR, source, message, null, null, null);
    }

    public static void error(String source, String message, Exception problem) {
        enqueue(Level.ERROR, source, message, problem, null, null);
    }

    public static void error(String source, String message, Exception problem, String payload) {
        enqueue(Level.ERROR, source, message, problem, null, payload);
    }

    public static void warn(String source, String message) {
        enqueue(Level.WARN, source, message, null, null, null);
    }

    public static void info(String source, String message) {
        enqueue(Level.INFO, source, message, null, null, null);
    }

    public static void info(String source, String message, Id recordId) {
        enqueue(Level.INFO, source, message, null, recordId, null);
    }

    public static void debug(String source, String message) {
        enqueue(Level.DEBUG, source, message, null, null, null);
    }

    public static void logException(String source, String context, Exception problem) {
        String message = String.isBlank(context) ? ExceptionUtils.describe(problem) : context;
        enqueue(Level.ERROR, source, message, problem, null, null);
    }

    public static Integer pendingCount() {
        return BUFFER.size();
    }

    public static void flush() {
        if (BUFFER.isEmpty()) {
            return;
        }

        List<ApplicationLog__c> entries = new List<ApplicationLog__c>(BUFFER);
        BUFFER.clear();

        try {
            List<Database.SaveResult> results = Database.insert(entries, false, AccessLevel.SYSTEM_MODE);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'LogService could not persist a log entry: ' + result.getErrors());
                }
            }
        } catch (Exception problem) {
            System.debug(LoggingLevel.ERROR, 'LogService flush failed: ' + ExceptionUtils.describe(problem));
        }
    }

    @TestVisible
    private static void reset() {
        BUFFER.clear();
    }

    private static void enqueue(Level level, String source, String message, Exception problem, Id recordId, String payload) {
        ApplicationLog__c entry = new ApplicationLog__c(
            Level__c = level.name(),
            Source__c = truncate(source, 255),
            Message__c = truncate(message, MESSAGE_LIMIT),
            Record_Id__c = recordId,
            Payload__c = truncate(payload, MESSAGE_LIMIT),
            Logged_At__c = Datetime.now()
        );

        if (problem != null) {
            entry.Exception_Type__c = truncate(problem.getTypeName(), 255);
            entry.Stack_Trace__c = truncate(problem.getStackTraceString(), STACK_TRACE_LIMIT);
            entry.Line_Number__c = problem.getLineNumber();
        }

        BUFFER.add(entry);
        if (BUFFER.size() >= MAX_BUFFER_SIZE) {
            flush();
        }
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
