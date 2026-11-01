/**
 * Helpers for tests that need a second user or a concise assertion.
 *
 * Users are created with a unique username so repeated runs in the same org never collide.
 */
@IsTest
public class TestUtils {
    private TestUtils() {
    }

    public static User createUser(String profileName) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String suffix =
            String.valueOf(Datetime.now().getTime()) +
            String.valueOf(Math.abs(Crypto.getRandomInteger()));

        User testUser = new User(
            FirstName = 'Framework',
            LastName = 'Test User',
            Email = 'architect.stack.' + suffix + '@example.com',
            Username = 'architect.stack.' + suffix + '@example.com',
            Alias = ('t' + suffix).left(8),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id
        );
        insert testUser;
        return testUser;
    }

    public static void assignPermissionSet(Id userId, String permissionSetApiName) {
        PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetApiName LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSet.Id);
    }

    public static void assertNoErrors(List<Database.SaveResult> results) {
        for (Database.SaveResult result : results) {
            Assert.isTrue(result.isSuccess(), 'Unexpected DML failure: ' + String.valueOf(result.getErrors()));
        }
    }
}
