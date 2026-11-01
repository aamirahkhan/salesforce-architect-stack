@IsTest
private class SObjectSelector_TEST {
    @IsTest
    static void selectsDeclaredFieldsById() {
        List<Account> accounts = TestDataFactory.insertAccounts(2);
        Set<Id> recordIds = new Map<Id, Account>(accounts).keySet();

        List<Account> found = new AccountSelector().selectByIds(recordIds);

        Assert.areEqual(2, found.size());
        Assert.isNotNull(found[0].Name, 'The declared field list must be queried.');
    }

    @IsTest
    static void returnsEmptyListsForEmptyFilters() {
        AccountSelector selector = new AccountSelector();

        Assert.areEqual(0, selector.selectByIds(new Set<Id>()).size());
        Assert.areEqual(0, selector.selectByField(Account.Rating, new Set<Object>()).size());
    }

    @IsTest
    static void selectsByFieldValue() {
        TestDataFactory.insertAccounts(1);

        List<SObject> found = new AccountSelector().selectByField(Account.Rating, new Set<Object>{ 'Warm' });

        Assert.isTrue(found.size() >= 1, 'The selector should find the seeded account by rating.');
    }

    @IsTest
    static void selectsWithBoundQuery() {
        Account account = TestDataFactory.insertAccount('Bound Query');

        List<SObject> found = new AccountSelector()
            .selectByQuery('Name = :accountName', new Map<String, Object>{ 'accountName' => account.Name });

        Assert.areEqual(1, found.size());
    }

    @IsTest
    static void buildsIdMap() {
        List<Account> accounts = TestDataFactory.insertAccounts(2);

        Map<Id, Account> byId = new AccountSelector().selectByIdMap(new Map<Id, Account>(accounts).keySet());

        Assert.areEqual(2, byId.size());
        Assert.isNotNull(byId.get(accounts[0].Id));
    }
}
