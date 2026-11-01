/**
 * Builders and inserts for test data.
 *
 * Tests that hand-build a dozen SObject fields are the main reason a suite rots: one new required
 * field and hundreds of tests fail for an unrelated reason. Build through the factory instead, and
 * override only the fields the test is actually about.
 */
@IsTest
public class TestDataFactory {
    private TestDataFactory() {
    }

    public static Account buildAccount(String name) {
        return new Account(Name = name, BillingCountry = 'US', Rating = 'Warm');
    }

    public static List<Account> buildAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer index = 0; index < count; index++) {
            accounts.add(buildAccount('Test Account ' + index));
        }
        return accounts;
    }

    public static List<Contact> buildContacts(Id accountId, Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer index = 0; index < count; index++) {
            contacts.add(new Contact(LastName = 'Test Contact ' + index, AccountId = accountId));
        }
        return contacts;
    }

    public static List<Opportunity> buildOpportunities(Id accountId, Integer count) {
        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer index = 0; index < count; index++) {
            opportunities.add(
                new Opportunity(
                    Name = 'Test Opportunity ' + index,
                    AccountId = accountId,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30),
                    Amount = 1000
                )
            );
        }
        return opportunities;
    }

    public static Account insertAccount(String name) {
        Account account = buildAccount(name);
        insertRecords(new List<SObject>{ account });
        return account;
    }

    public static List<Account> insertAccounts(Integer count) {
        List<Account> accounts = buildAccounts(count);
        insertRecords(accounts);
        return accounts;
    }

    public static void insertRecords(List<SObject> records) {
        List<Database.SaveResult> results = Database.insert(records, false);
        assertAllSucceeded(results);
    }

    public static void assertAllSucceeded(List<Database.SaveResult> results) {
        for (Database.SaveResult result : results) {
            Assert.isTrue(result.isSuccess(), 'Unexpected DML failure: ' + String.valueOf(result.getErrors()));
        }
    }
}
