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
    static void stripsFieldsTheRunningUserCannotWrite() {
        ApplicationLog__c entry = new ApplicationLog__c(
            Level__c = 'ERROR',
            Source__c = 'AccessGuard_TEST',
            Message__c = 'Sensitive details'
        );
        // Setup writes telemetry in system mode so the test proves stripping, not the runner's FLS.
        Database.insert(entry, AccessLevel.SYSTEM_MODE);

        ApplicationLog__c stored = [
            SELECT Id, Message__c
            FROM ApplicationLog__c
            WHERE Id = :entry.Id
            WITH SYSTEM_MODE
        ];

        // The admin permission set grants object create but leaves fields read-only, which is the
        // shape CREATEABLE stripping needs: object access, no field write access.
        User standardUser = TestUtils.createUser('Standard User');
        TestUtils.assignPermissionSet(standardUser.Id, 'Architect_Stack_Admin');

        System.runAs(standardUser) {
            List<SObject> stripped = AccessGuard.stripInaccessible(
                new List<SObject>{ stored },
                AccessType.CREATABLE,
                false
            );

            Assert.areEqual(1, stripped.size());
            Assert.isNull(
                stripped[0].getPopulatedFieldsAsMap().get('Message__c'),
                'A field the running user cannot write must be stripped.'
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
