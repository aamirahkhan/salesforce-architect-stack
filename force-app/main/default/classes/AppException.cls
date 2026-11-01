/**
 * Structured exception used by application, domain and integration code.
 *
 * Every failure carries an error code so callers, logs and integrations can branch on
 * the kind of problem without parsing messages. Throw these from services and domains;
 * let unexpected platform exceptions bubble up unchanged.
 */
public class AppException extends Exception {
    public static final String VALIDATION = 'VALIDATION';
    public static final String NOT_FOUND = 'NOT_FOUND';
    public static final String SECURITY = 'SECURITY';
    public static final String CONFIGURATION = 'CONFIGURATION';
    public static final String DML = 'DML';
    public static final String INTEGRATION = 'INTEGRATION';
    public static final String ASYNC = 'ASYNC';
    public static final String UNKNOWN = 'UNKNOWN';

    public String errorCode = UNKNOWN;
    public List<Id> recordIds = new List<Id>();
    public String fieldName;
    public String correlationId;

    public static AppException of(String errorCode, String message) {
        AppException problem = new AppException(message);
        if (String.isNotBlank(errorCode)) {
            problem.errorCode = errorCode;
        }
        return problem;
    }

    public static AppException validation(String message) {
        return of(VALIDATION, message);
    }

    public static AppException notFound(String message) {
        return of(NOT_FOUND, message);
    }

    public static AppException security(String message) {
        return of(SECURITY, message);
    }

    public static AppException configuration(String message) {
        return of(CONFIGURATION, message);
    }

    public static AppException dml(String message) {
        return of(DML, message);
    }

    public static AppException integration(String message) {
        return of(INTEGRATION, message);
    }

    public static AppException async(String message) {
        return of(ASYNC, message);
    }

    public AppException withRecordIds(List<Id> ids) {
        if (ids != null && !ids.isEmpty()) {
            recordIds.addAll(ids);
        }
        return this;
    }

    public AppException withRecordId(Id recordId) {
        if (recordId != null) {
            recordIds.add(recordId);
        }
        return this;
    }

    public AppException withField(String apiName) {
        this.fieldName = apiName;
        return this;
    }

    public AppException withCorrelationId(String value) {
        this.correlationId = value;
        return this;
    }

    public String describe() {
        return errorCode + ': ' + getMessage();
    }
}
