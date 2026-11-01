/**
 * Decides whether a trigger handler should run.
 *
 * Three layers, evaluated in order:
 *   1. Runtime bypass registered in this transaction (TriggerHandler.bypass).
 *   2. TriggerSetting__mdt: a record whose Is_Active__c is false disables the handler without a deployment.
 *   3. TriggerSetting__mdt: an optional Bypass_Custom_Permission__c grants a controlled bypass to
 *      integration users running data loads.
 *
 * Metadata is read once per transaction. Call refresh() from tests after changing settings.
 */
public class TriggerControl {
    private static final Set<String> BYPASSED = new Set<String>();
    private static Map<String, TriggerSetting__mdt> settingsByHandlerName;

    private TriggerControl() {
    }

    public static Boolean isBypassed(String handlerName) {
        if (String.isBlank(handlerName)) {
            return false;
        }
        if (BYPASSED.contains(handlerName)) {
            return true;
        }

        TriggerSetting__mdt setting = settings().get(handlerName);
        if (setting == null) {
            return false;
        }
        if (setting.Is_Active__c != true) {
            return true;
        }

        String permissionName = setting.Bypass_Custom_Permission__c;
        return String.isNotBlank(permissionName) && FeatureManagement.checkPermission(permissionName);
    }

    public static void bypass(String handlerName) {
        if (String.isBlank(handlerName)) {
            throw AppException.configuration('A trigger handler name is required to register a bypass.');
        }
        BYPASSED.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        BYPASSED.remove(handlerName);
    }

    public static void clearAllBypasses() {
        BYPASSED.clear();
    }

    @TestVisible
    private static void refresh() {
        settingsByHandlerName = null;
    }

    private static Map<String, TriggerSetting__mdt> settings() {
        if (settingsByHandlerName == null) {
            settingsByHandlerName = new Map<String, TriggerSetting__mdt>();
            for (TriggerSetting__mdt setting : [
                SELECT DeveloperName, Is_Active__c, Bypass_Custom_Permission__c
                FROM TriggerSetting__mdt
            ]) {
                settingsByHandlerName.put(setting.DeveloperName, setting);
            }
        }
        return settingsByHandlerName;
    }
}
