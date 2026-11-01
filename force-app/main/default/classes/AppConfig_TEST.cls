@IsTest
private class AppConfig_TEST {
    @IsTest
    static void readsDeployedConfiguration() {
        Assert.areEqual(200, AppConfig.getInteger('DefaultBatchSize', 25));
        Assert.isTrue(AppConfig.getBoolean('Enable_Strict_Validation', false));

        List<String> allowedCountries = AppConfig.getStringList('AllowedBillingCountries', ',');
        Assert.areEqual(3, allowedCountries.size());
        Assert.isTrue(allowedCountries.contains('US'));
        Assert.isTrue(AppConfig.has('AllowedBillingCountries'));
    }

    @IsTest
    static void fallsBackWhenKeyIsMissing() {
        Assert.areEqual('fallback', AppConfig.getString('Missing_Key', 'fallback'));
        Assert.areEqual(25, AppConfig.getInteger('Missing_Key', 25));
        Assert.isFalse(AppConfig.getBoolean('Missing_Key', false));
        Assert.isFalse(AppConfig.has('Missing_Key'));
        Assert.areEqual(0, AppConfig.getStringList('Missing_Key', ',').size());
    }

    @IsTest
    static void rejectsMalformedNumbers() {
        try {
            AppConfig.getInteger('AllowedBillingCountries', 0);
            Assert.fail('Expected a configuration error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.CONFIGURATION, problem.errorCode);
        }

        try {
            AppConfig.getDecimal('AllowedBillingCountries', 0);
            Assert.fail('Expected a configuration error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.CONFIGURATION, problem.errorCode);
        }
    }

    @IsTest
    static void rejectsMalformedBooleans() {
        try {
            AppConfig.getBoolean('AllowedBillingCountries', false);
            Assert.fail('Expected a configuration error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.CONFIGURATION, problem.errorCode);
        }
    }
}
