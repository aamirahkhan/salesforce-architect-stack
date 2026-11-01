/**
 * Typed access to runtime configuration stored in Custom Metadata (AppConfig__mdt).
 *
 * Keys are the metadata record DeveloperNames, so configuration is deployable,
 * version-controlled and environment specific without code changes. Values are read
 * once per transaction; call clearCache() from tests that change assumptions.
 *
 * Missing keys return the supplied fallback. Malformed values throw a configuration
 * error instead of silently falling back, because a wrong batch size or flag in
 * production should fail loudly during the deploying pull request, not quietly at 2am.
 */
public class AppConfig {
    private static Map<String, AppConfig__mdt> cache;

    private AppConfig() {
    }

    public static Boolean has(String key) {
        return settings().containsKey(key);
    }

    public static String getString(String key, String fallback) {
        AppConfig__mdt setting = settings().get(key);
        if (setting == null || String.isBlank(setting.Value__c)) {
            return fallback;
        }
        return setting.Value__c;
    }

    public static String getString(String key) {
        return getString(key, null);
    }

    public static Boolean getBoolean(String key, Boolean fallback) {
        String raw = getString(key, null);
        if (String.isBlank(raw)) {
            return fallback;
        }

        String normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
            return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
            return false;
        }
        throw AppException.configuration('AppConfig "' + key + '" is not a boolean: ' + raw);
    }

    public static Integer getInteger(String key, Integer fallback) {
        String raw = getString(key, null);
        if (String.isBlank(raw)) {
            return fallback;
        }
        try {
            return Integer.valueOf(raw.trim());
        } catch (Exception problem) {
            throw AppException.configuration('AppConfig "' + key + '" is not an integer: ' + raw);
        }
    }

    public static Decimal getDecimal(String key, Decimal fallback) {
        String raw = getString(key, null);
        if (String.isBlank(raw)) {
            return fallback;
        }
        try {
            return Decimal.valueOf(raw.trim());
        } catch (Exception problem) {
            throw AppException.configuration('AppConfig "' + key + '" is not a decimal: ' + raw);
        }
    }

    public static List<String> getStringList(String key, String delimiter) {
        List<String> values = new List<String>();
        String raw = getString(key, null);
        if (String.isBlank(raw) || String.isBlank(delimiter)) {
            return values;
        }
        for (String part : raw.split(Pattern.quote(delimiter))) {
            if (String.isNotBlank(part)) {
                values.add(part.trim());
            }
        }
        return values;
    }

    @TestVisible
    private static void clearCache() {
        cache = null;
    }

    private static Map<String, AppConfig__mdt> settings() {
        if (cache == null) {
            cache = new Map<String, AppConfig__mdt>();
            for (AppConfig__mdt setting : [SELECT DeveloperName, Value__c FROM AppConfig__mdt]) {
                cache.put(setting.DeveloperName, setting);
            }
        }
        return cache;
    }
}
