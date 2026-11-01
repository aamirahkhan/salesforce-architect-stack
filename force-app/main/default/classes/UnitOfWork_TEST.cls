@IsTest
private class UnitOfWork_TEST {
    @IsTest
    static void insertsUpdatesAndDeletes() {
        Account account = TestDataFactory.buildAccount('Unit Of Work');

        new UnitOfWork().registerNew(account).commitWork();
        Assert.isNotNull(account.Id, 'Insert should assign an Id.');

        account.Rating = 'Hot';
        new UnitOfWork().registerDirty(account).commitWork();
        Assert.areEqual('Hot', [SELECT Rating FROM Account WHERE Id = :account.Id].Rating);

        Set<Id> recordIds = new Set<Id>{ account.Id };
        new UnitOfWork().registerDeleted(account).commitWork();
        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Id IN :recordIds]);
    }

    @IsTest
    static void rollsBackEveryRecordWhenOneFails() {
        Integer startingCount = [SELECT COUNT() FROM Account];

        Account validAccount = TestDataFactory.buildAccount('Valid');
        Account invalidAccount = new Account();

        UnitOfWork unitOfWork = new UnitOfWork();
        unitOfWork.registerNew(validAccount).registerNew(invalidAccount);

        try {
            unitOfWork.commitWork();
            Assert.fail('Expected a DML error for the account without a name.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.DML, problem.errorCode);
        }

        Assert.areEqual(startingCount, [SELECT COUNT() FROM Account], 'The valid record must be rolled back too.');
    }

    @IsTest
    static void rejectsRecordsWithoutAnId() {
        try {
            new UnitOfWork().registerDirty(new Account(Name = 'Unsaved'));
            Assert.fail('Expected a configuration error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.CONFIGURATION, problem.errorCode);
        }
    }

    @IsTest
    static void doesNothingWhenEmpty() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Assert.isTrue(unitOfWork.isEmpty());
        Assert.areEqual(0, unitOfWork.size());

        unitOfWork.commitWork();
        Assert.isTrue(unitOfWork.isEmpty());
    }
}
