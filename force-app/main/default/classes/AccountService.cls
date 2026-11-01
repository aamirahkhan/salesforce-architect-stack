/**
 * Transactional use cases for Account.
 *
 * A service is the only layer that composes access checks, queries, domain rules and DML. It is
 * callable from a trigger handler, an LWC, a Flow or an async job without duplicating logic, and it
 * is where a caller would look to understand what a business operation actually does.
 */
public with sharing class AccountService {
    private static final Set<String> VALID_RATINGS = new Set<String>{ 'Hot', 'Warm', 'Cold' };

    /**
     * Sets the rating of a single account on behalf of the running user.
     * Enforces object permissions, then read access via the selector and write access via the unit of work.
     */
    @AuraEnabled
    public static void updateRating(Id accountId, String rating) {
        if (accountId == null) {
            throw AppException.validation('An account id is required.').withField('Id');
        }
        if (String.isBlank(rating) || !VALID_RATINGS.contains(rating)) {
            throw AppException.validation('Rating must be Hot, Warm or Cold.').withField('Rating');
        }

        AccessGuard.requireUpdateable(Account.SObjectType);

        List<Account> accounts = new AccountSelector().selectByIds(new Set<Id>{ accountId });
        if (accounts.isEmpty()) {
            throw AppException.notFound('Account not found or not accessible: ' + accountId).withRecordId(accountId);
        }

        Account account = accounts[0];
        account.Rating = rating;
        new UnitOfWork().registerDirty(account).commitWork();

        LogService.info('AccountService', 'Rating changed to ' + rating, accountId);
        LogService.flush();
    }
}
