/**
 * Safe helpers for reading details from any Exception.
 *
 * Logging code must never fail because it tried to read a property that is only
 * available on some exception types, so every accessor is null-safe.
 */
public class ExceptionUtils {
    private ExceptionUtils() {
    }

    public static String describe(Exception problem) {
        if (problem == null) {
            return null;
        }
        return problem.getTypeName() + ': ' + problem.getMessage();
    }

    public static String stackTrace(Exception problem) {
        return problem == null ? null : problem.getStackTraceString();
    }

    public static Integer lineNumber(Exception problem) {
        return problem == null ? null : problem.getLineNumber();
    }

    public static String typeName(Exception problem) {
        return problem == null ? null : problem.getTypeName();
    }

    /** True when the transaction failed on a governor limit rather than on business rules. */
    public static Boolean isLimitException(Exception problem) {
        String type = typeName(problem);
        return type != null && type.contains('LimitException');
    }
}
