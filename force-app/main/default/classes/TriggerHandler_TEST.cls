@IsTest
private class TriggerHandler_TEST {
    @IsTest
    static void runsHandlerInsideATriggerContext() {
        Account account = TestDataFactory.buildAccount('Trigger Handler');
        account.Website = 'HTTPS://WWW.Example.COM/';

        Test.startTest();
        insert account;
        Test.stopTest();

        Account saved = [SELECT Website FROM Account WHERE Id = :account.Id];
        Assert.areEqual('example.com', saved.Website, 'before insert should normalize the website.');
    }

    @IsTest
    static void bypassesHandlerAtRuntime() {
        TriggerHandler.bypass('AccountTriggerHandler');

        Account account = TestDataFactory.buildAccount('Bypassed Handler');
        account.Website = 'HTTPS://WWW.Example.COM/';
        account.BillingCountry = 'ZZ';

        Test.startTest();
        insert account;
        Test.stopTest();

        Account saved = [SELECT Website, BillingCountry FROM Account WHERE Id = :account.Id];
        Assert.areEqual('HTTPS://WWW.Example.COM/', saved.Website, 'A bypassed handler must make no changes.');
        Assert.areEqual('ZZ', saved.BillingCountry, 'A bypassed handler must skip validation.');

        TriggerHandler.clearBypass('AccountTriggerHandler');
    }

    @IsTest
    static void rejectsNullHandler() {
        try {
            TriggerDispatcher.run(null);
            Assert.fail('Expected a configuration error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.CONFIGURATION, problem.errorCode);
        }
    }

    @IsTest
    static void rejectsExecutionOutsideATrigger() {
        try {
            new AccountTriggerHandler().run();
            Assert.fail('Expected a configuration error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.CONFIGURATION, problem.errorCode);
            Assert.isTrue(problem.getMessage().contains('trigger context'));
        }
    }

    @IsTest
    static void exposesHandlerName() {
        Assert.areEqual('AccountTriggerHandler', new AccountTriggerHandler().getHandlerName());
    }
}
