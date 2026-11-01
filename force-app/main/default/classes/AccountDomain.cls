/**
 * Business rules that apply to Account regardless of entry point.
 *
 * Website normalization and the billing country allowlist are deliberately boring rules: they
 * demonstrate where logic belongs, not how clever the framework is. Copy the shape, replace the
 * rules.
 */
public with sharing class AccountDomain extends SObjectDomain {
    public AccountDomain(List<Account> accounts) {
        super(accounts);
    }

    /** Trims, lowercases and removes protocol, "www." and a trailing slash from Website. */
    public void normalizeWebsite() {
        for (Account account : accounts()) {
            if (String.isBlank(account.Website)) {
                continue;
            }
            String normalized = account.Website.trim().toLowerCase();
            normalized = normalized.removeStart('https://').removeStart('http://').removeStart('www.');
            normalized = normalized.removeEnd('/');
            account.Website = normalized;
        }
    }

    /** Rejects billing countries outside the AppConfig "AllowedBillingCountries" allowlist. */
    public void validateBillingCountry() {
        List<String> allowedCountries = AppConfig.getStringList('AllowedBillingCountries', ',');
        if (allowedCountries.isEmpty()) {
            return;
        }

        Set<String> allowed = new Set<String>();
        for (String country : allowedCountries) {
            allowed.add(country.toUpperCase());
        }

        for (Account account : accounts()) {
            if (String.isBlank(account.BillingCountry)) {
                continue;
            }
            if (!allowed.contains(account.BillingCountry.trim().toUpperCase())) {
                addFieldError(
                    account,
                    Account.BillingCountry,
                    'Billing country must be one of: ' + String.join(allowedCountries, ', ')
                );
            }
        }
    }

    private List<Account> accounts() {
        return (List<Account>) getRecords();
    }
}
