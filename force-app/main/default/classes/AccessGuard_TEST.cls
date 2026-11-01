@IsTest
private class AccessGuard_TEST {
    @IsTest
    static void permitsAccountAccessForAdministrators() {
        AccessGuard.requireReadable(Account.SObjectType);
        AccessGuard.requireCreateable(Account.SObjectType);
        AccessGuard.requireUpdateable(Account.SObjectType);
        AccessGuard.requireDeletable(Account.SObjectType);
    }

    @IsTest
    static void requiresCustomPermission() {
        User standardUser = TestUtils.createUser('Standard User');

        System.runAs(standardUser) {
            Assert.isFalse(AccessGuard.hasPermission('Bypass_Trigger_Framework'));
            try {
                AccessGuard.requirePermission('Bypass_Trigger_Framework');
                Assert.fail('Expected a security error.');
            } catch (AppException problem) {
                Assert.areEqual(AppException.SECURITY, problem.errorCode);
            }
        }
    }

    @IsTest
    static void stripsFieldsTheRunningUserCannotRead() {
        ApplicationLog__c entry = new ApplicationLog__c(
            Level__c = 'ERROR',
            Source__c = 'AccessGuard_TEST',
            Message__c = 'Sensitive details'
        );
        insert entry;

        User standardUser = TestUtils.createUser('Standard User');
        List<ApplicationLog__c> logs = [SELECT Id, Message__c FROM ApplicationLog__c WHERE Id = :entry.Id];

        System.runAs(standardUser) {
            List<SObject> records = new List<SObject>();
            records.addAll(logs);

            List<SObject> stripped = AccessGuard.stripInaccessible(records, AccessType.READABLE, false);

            Assert.areEqual(1, stripped.size());
            Assert.isTrue(
                String.isBlank(((ApplicationLog__c) stripped[0]).Message__c),
                'A field the running user cannot read must be stripped.'
            );
        }
    }

    @IsTest
    static void keepsAccessibleFields() {
        Account account = TestDataFactory.insertAccount('Access Guard');

        List<SObject> records = new List<SObject>{ account };
        List<SObject> stripped = AccessGuard.stripInaccessible(records, AccessType.READABLE, true);

        Assert.areEqual(1, stripped.size());
        Assert.areEqual(account.Id, stripped[0].Id);
    }
}
