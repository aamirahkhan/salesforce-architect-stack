@IsTest
private class LogService_TEST {
    @IsTest
    static void persistsBufferedEntriesWithExceptionDetails() {
        LogService.reset();

        try {
            throw AppException.validation('Boom');
        } catch (Exception problem) {
            LogService.error('LogService_TEST', 'Something failed', problem, '{"key":"value"}');
        }

        Assert.areEqual(1, LogService.pendingCount(), 'Entries should buffer until the flush.');

        LogService.flush();

        Assert.areEqual(0, LogService.pendingCount());

        ApplicationLog__c entry = [
            SELECT Level__c, Source__c, Message__c, Exception_Type__c, Line_Number__c, Payload__c
            FROM ApplicationLog__c
            LIMIT 1
        ];
        Assert.areEqual('ERROR', entry.Level__c);
        Assert.areEqual('LogService_TEST', entry.Source__c);
        Assert.isTrue(entry.Message__c.contains('Something failed'));
        Assert.isNotNull(entry.Exception_Type__c, 'The exception type should be captured.');
        Assert.areEqual('{"key":"value"}', entry.Payload__c);
    }

    @IsTest
    static void recordsRecordIdForInfoEntries() {
        LogService.reset();
        Account account = TestDataFactory.insertAccount('Log Target');

        LogService.info('AccountService', 'Rating changed', account.Id);
        LogService.flush();

        ApplicationLog__c entry = [SELECT Level__c, Record_Id__c FROM ApplicationLog__c LIMIT 1];
        Assert.areEqual('INFO', entry.Level__c);
        Assert.areEqual(String.valueOf(account.Id), entry.Record_Id__c);
    }

    @IsTest
    static void flushingWithoutEntriesDoesNothing() {
        LogService.reset();
        LogService.flush();

        Assert.areEqual(0, [SELECT COUNT() FROM ApplicationLog__c]);
    }
}
