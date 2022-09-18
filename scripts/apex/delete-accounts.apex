// Some scratch orgs come with entitlements setup
// so we have to delete them as well
List<Entitlement> entitlements = [SELECT Id, Name FROM Entitlement];
delete entitlements;

// Delete all Accounts
List<Account> accounts = [SELECT Id, Name FROM Account];
delete accounts;