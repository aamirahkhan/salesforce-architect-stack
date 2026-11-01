@IsTest
private class AccountService_TEST {
    @IsTest
    static void updatesRating() {
        Account account = TestDataFactory.insertAccount('Service Target');

        Test.startTest();
        AccountService.updateRating(account.Id, 'Hot');
        Test.stopTest();

        Assert.areEqual('Hot', [SELECT Rating FROM Account WHERE Id = :account.Id].Rating);
    }

    @IsTest
    static void rejectsInvalidRating() {
        Account account = TestDataFactory.insertAccount('Service Target');

        try {
            AccountService.updateRating(account.Id, 'Lukewarm');
            Assert.fail('Expected a validation error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.VALIDATION, problem.errorCode);
            Assert.areEqual('Rating', problem.fieldName);
        }
    }

    @IsTest
    static void rejectsMissingAccountId() {
        try {
            AccountService.updateRating(null, 'Hot');
            Assert.fail('Expected a validation error.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.VALIDATION, problem.errorCode);
        }
    }

    @IsTest
    static void doesNotChangeUnselectedAccounts() {
        Account first = TestDataFactory.insertAccount('First');
        Account second = TestDataFactory.insertAccount('Second');

        AccountService.updateRating(first.Id, 'Cold');

        Assert.areEqual('Cold', [SELECT Rating FROM Account WHERE Id = :first.Id].Rating);
        Assert.areEqual('Warm', [SELECT Rating FROM Account WHERE Id = :second.Id].Rating);
    }
}
