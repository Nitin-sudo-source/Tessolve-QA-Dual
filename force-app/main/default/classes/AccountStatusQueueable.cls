public class AccountStatusQueueable implements Queueable {
    
    private List<Id> accountIds;
    
    public AccountStatusQueueable(List<Id> accountIds) {
        this.accountIds = accountIds;
    }
    
    public void execute(QueueableContext context) {
        
        try {
            
            // Null / Empty check
            if (accountIds == null || accountIds.isEmpty()) {
                return;
            }
            
            // Remove duplicates + null safety
            Set<Id> accIdSet = new Set<Id>();
            for (Id accId : accountIds) {
                if (accId != null) {
                    accIdSet.add(accId);
                }
            }
            
            if (accIdSet.isEmpty()) {
                return;
            }
            
            // Aggregate Maps (Won / Active / Lost)
            Map<Id, Integer> wonCountByAcc    = getOppCountByAccount(accIdSet, true,  'Closed Won');
            Map<Id, Integer> activeCountByAcc = getOppCountByAccount(accIdSet, false, null);
            Map<Id, Integer> lostCountByAcc   = getOppCountByAccount(accIdSet, true,  'Closed Lost');
            
            //  Query Accounts once
            List<Account> accList = [
                SELECT Id, Account_Status__c
                FROM Account
                WHERE Id IN :accIdSet
            ];
            
            if (accList.isEmpty()) {
                return;
            }
            
            // Build update list (only changed)
            List<Account> toUpdate = new List<Account>();
            
            for (Account acc : accList) {
                
                Integer won    = wonCountByAcc.containsKey(acc.Id) ? wonCountByAcc.get(acc.Id) : 0;
                Integer active = activeCountByAcc.containsKey(acc.Id) ? activeCountByAcc.get(acc.Id) : 0;
                Integer lost   = lostCountByAcc.containsKey(acc.Id) ? lostCountByAcc.get(acc.Id) : 0;
                
                String newStatus;
                
                // Priority logic
                if (won > 0) {
                    newStatus = 'Won Account';
                } else if (active > 0) {
                    newStatus = 'Prospect Account';
                } else if (lost > 0) {
                    newStatus = 'Lost Account';
                } else {
                    //  No opportunities
                    newStatus = 'Prospect Account'; // or null as per business
                }
                
                // Only update if changed
                if (acc.Account_Status__c != newStatus) {
                    toUpdate.add(new Account(
                        Id = acc.Id,
                        Account_Status__c = newStatus
                    ));
                }
            }
            
            // DML only when needed
            if (!toUpdate.isEmpty()) {
                
                // Option 2: partial success (recommended for bulk)
                Database.SaveResult[] srList = Database.update(toUpdate, false);
                
                // Optional debug for failures (safe in production)
                for (Integer i = 0; i < srList.size(); i++) {
                    if (!srList[i].isSuccess()) {
                        for (Database.Error e : srList[i].getErrors()) {
                            System.debug('Account Update Failed: ' + toUpdate[i].Id + ' => ' + e.getMessage());
                        }
                    }
                }
            }
            
        } catch (Exception ex) {
            System.debug('AccountStatusQueueable Exception: ' + ex.getMessage() + ' Line: ' + ex.getLineNumber());
        }
    }
    
    // =========================================================
    // Helper: Aggregate Opp count by Account (no query in loop)
    // =========================================================
    private static Map<Id, Integer> getOppCountByAccount(
        Set<Id> accountIds,
        Boolean isClosed,
        String stageName
    ) {
        Map<Id, Integer> resultMap = new Map<Id, Integer>();
        
        if (accountIds == null || accountIds.isEmpty()) {
            return resultMap;
        }
        
        String baseQuery =
            'SELECT AccountId accId, COUNT(Id) cnt ' +
            'FROM Opportunity ' +
            'WHERE AccountId IN :accountIds ' +
            'AND IsDeleted = false ';
        
        if (isClosed != null) {
            baseQuery += 'AND IsClosed = :isClosed ';
        }
        
        if (stageName != null) {
            baseQuery += 'AND StageName = :stageName ';
        }
        
        baseQuery += 'GROUP BY AccountId';
        
        List<AggregateResult> agrList = Database.query(baseQuery);
        
        if (agrList != null && !agrList.isEmpty()) {
            for (AggregateResult ar : agrList) {
                resultMap.put((Id) ar.get('accId'), (Integer) ar.get('cnt'));
            }
        }
        
        return resultMap;
    }
}