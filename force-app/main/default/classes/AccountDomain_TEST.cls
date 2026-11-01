@IsTest
private class AccountDomain_TEST {
    @IsTest
    static void normalizesWebsite() {
        Account account = TestDataFactory.buildAccount('Website');
        account.Website = '  HTTPS://WWW.Example.COM/Path/  ';

        new AccountDomain(new List<Account>{ account }).normalizeWebsite();

        Assert.areEqual('example.com/path', account.Website);
    }

    @IsTest
    static void leavesBlankWebsitesAlone() {
        Account account = TestDataFactory.buildAccount('No Website');
        account.Website = null;

        new AccountDomain(new List<Account>{ account }).normalizeWebsite();

        Assert.isNull(account.Website);
    }

    @IsTest
    static void rejectsCountryOutsideTheAllowlist() {
        Account account = TestDataFactory.buildAccount('Invalid Country');
        account.BillingCountry = 'ZZ';

        Database.SaveResult result = Database.insert(account, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains('Billing country must be one of'),
            'Expected a field error naming the allowlist.'
        );
    }

    @IsTest
    static void acceptsBlankCountry() {
        Account account = TestDataFactory.buildAccount('No Country');
        account.BillingCountry = null;

        Database.SaveResult result = Database.insert(account, false);

        Assert.isTrue(result.isSuccess(), 'A blank country should skip the allowlist.');
    }

    @IsTest
    static void acceptsAllowlistedCountryCaseInsensitively() {
        Account account = TestDataFactory.buildAccount('Lowercase Country');
        account.BillingCountry = 'us';

        Database.SaveResult result = Database.insert(account, false);

        Assert.isTrue(result.isSuccess());
    }
}
