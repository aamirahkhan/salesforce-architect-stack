/**
 * Every Account query in the application goes through here.
 *
 * The field list is explicit. When a caller needs a new field, it is added here once and every
 * consumer sees it; query cost stays visible in one diff instead of spreading across the codebase.
 */
public with sharing class AccountSelector extends SObjectSelector {
    public override SObjectType getSObjectType() {
        return Account.SObjectType;
    }

    protected override List<SObjectField> getFields() {
        return new List<SObjectField>{
            Account.Id,
            Account.Name,
            Account.Rating,
            Account.Website,
            Account.BillingCountry
        };
    }

    protected override List<String> getOrderBy() {
        return new List<String>{ 'Name' };
    }

    public List<Account> selectByIds(Set<Id> recordIds) {
        return (List<Account>) selectById(recordIds);
    }

    public Map<Id, Account> selectByIdMap(Set<Id> recordIds) {
        Map<Id, Account> accountsById = new Map<Id, Account>();
        for (Account account : selectByIds(recordIds)) {
            accountsById.put(account.Id, account);
        }
        return accountsById;
    }
}
