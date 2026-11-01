/**
 * Trigger orchestration for Account. No business rules live here: it decides which domain rules
 * apply in which context and delegates immediately.
 */
public with sharing class AccountTriggerHandler extends TriggerHandler {
    public override SObjectType getSObjectType() {
        return Account.SObjectType;
    }

    protected override void beforeInsert() {
        applyDomainRules((List<Account>) getNewRecords());
    }

    protected override void beforeUpdate() {
        applyDomainRules((List<Account>) getNewRecords());
    }

    private void applyDomainRules(List<Account> accounts) {
        AccountDomain domain = new AccountDomain(accounts);
        domain.normalizeWebsite();
        domain.validateBillingCountry();
    }
}
