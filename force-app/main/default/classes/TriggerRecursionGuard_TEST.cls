@IsTest
private class TriggerRecursionGuard_TEST {
    @IsTest
    static void detectsRecordsHandledInTheCurrentTransaction() {
        List<Account> accounts = TestDataFactory.insertAccounts(2);
        Set<Id> bothRecordIds = new Map<Id, Account>(accounts).keySet();
        Set<Id> firstRecordId = new Set<Id>{ accounts[0].Id };

        Assert.isFalse(TriggerRecursionGuard.isHandled('AccountHandler', bothRecordIds));

        TriggerRecursionGuard.markHandled('AccountHandler', firstRecordId);

        Assert.isTrue(TriggerRecursionGuard.isHandled('AccountHandler', firstRecordId));
        Assert.isFalse(TriggerRecursionGuard.isHandled('AccountHandler', bothRecordIds));
        Assert.isFalse(TriggerRecursionGuard.isHandled('OtherHandler', firstRecordId));

        TriggerRecursionGuard.markHandled('AccountHandler', bothRecordIds);
        Assert.isTrue(TriggerRecursionGuard.isHandled('AccountHandler', bothRecordIds));
    }

    @IsTest
    static void ignoresEmptyScopesAndEmptyRecordSets() {
        List<Account> accounts = TestDataFactory.insertAccounts(1);
        Set<Id> recordIds = new Set<Id>{ accounts[0].Id };

        TriggerRecursionGuard.markHandled('', recordIds);
        TriggerRecursionGuard.markHandled(null, recordIds);
        TriggerRecursionGuard.markHandled('AccountHandler', new Set<Id>());

        Assert.isFalse(TriggerRecursionGuard.isHandled('', recordIds));
        Assert.isFalse(TriggerRecursionGuard.isHandled('AccountHandler', new Set<Id>()));
        Assert.isFalse(TriggerRecursionGuard.isHandled(null, recordIds));
    }
}
