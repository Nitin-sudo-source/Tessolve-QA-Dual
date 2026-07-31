public class OpportunityAccountStatusHandler {
    // Prevent recursion + prevent multiple queueable enqueues in same transaction
    private static Boolean jobQueued = false;
    private static Boolean currencyJobQueued = false;
   // private static Boolean isFromOpp = false;
    private static Boolean rliJobQueued = false;
    
    public static Set<Id> processedOpportunityIds = new Set<Id>();
    
    public static void beforeInsert(List<Opportunity> newList) {
        
        if (newList == null || newList.isEmpty()) return;
        
        Set<Id> parentOppIds = new Set<Id>();
        
        for (Opportunity oNew : newList) {
            if (oNew.Parent_Opportunity__c != null) {
                parentOppIds.add(oNew.Parent_Opportunity__c);
            }
        }
        
        System.debug('parentOppIds: ' + parentOppIds);
        
        // Pass list instead of map (safer for insert)
        if (!parentOppIds.isEmpty()) {
            OpportunityHandlerServices.validateParentAmount(parentOppIds, newList, null);
        }
    }
    
    /* public static void beforeUpdate(List<Opportunity> newList) {

if (newList == null || newList.isEmpty()) return;

Set<Id> parentOppIds = new Set<Id>();

for (Opportunity oNew : newList) {
if (oNew.Parent_Opportunity__c != null) {
parentOppIds.add(oNew.Parent_Opportunity__c);
}
}

System.debug('parentOppIds: ' + parentOppIds);

// Pass list instead of map (safer for insert)
if (!parentOppIds.isEmpty()) {
OpportunityHandlerServices.validateParentAmount(parentOppIds, newList);
}
}*/
    public static void beforeUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        
        if (newList == null || newList.isEmpty()) return;
        
        Set<Id> parentOppIds = new Set<Id>();
        
        for (Opportunity oNew : newList) {
            if (oNew.Parent_Opportunity__c != null) {
                parentOppIds.add(oNew.Parent_Opportunity__c);
            }
            // ALSO include old parent (re-parent case)
            if (oldMap.get(oNew.Id).Parent_Opportunity__c != null) {
                parentOppIds.add(oldMap.get(oNew.Id).Parent_Opportunity__c);
            }
        }
        
        if (!parentOppIds.isEmpty()) {
            OpportunityHandlerServices.validateParentAmount(parentOppIds, newList, oldMap);
        }
    }
    
    
    public static void afterInsert(List<Opportunity> newList) {
        Set<Id> parentOppIds = new Set<Id>();
        for (Opportunity oNew : newList) {
            if (oNew.Parent_Opportunity__c != null) {
                parentOppIds.add(oNew.Parent_Opportunity__c);
            }
        }
        System.debug('parentOppIds: '+parentOppIds);
        if (!parentOppIds.isEmpty()) {
            //OpportunityHandlerServices.rollupAmount(parentOppIds);
        }
        Set<Id> accIds = collectAccountIds(newList);
        enqueueJob(accIds);
    }
    
    public static void afterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }
        
        Set<Id> accIds = new Set<Id>();
        Set<Id> isCLosedIds = new Set<Id>();
        Map<Id, String> oppOldCurrencyMap = new Map<Id, String>();
        Set<Id> parentOppIds = new Set<Id>();
        Set<Id> isRLIOpp = new Set<Id>();
        
        
        for (Opportunity oNew : newList) {
            
            Opportunity oOld = oldMap.get(oNew.Id);
            if (oOld == null) continue;
            
            Boolean isAccountChanged = (oOld.AccountId != oNew.AccountId);
            Boolean isStageChanged   = (oOld.StageName != oNew.StageName);
            Boolean isCurrencyChanged = (oOld.CurrencyIsoCode != oNew.CurrencyIsoCode);
            
            Set<Id> tmRecordTypeIds = new Set<Id>();
            
            for (RecordType rt : [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Opportunity'
                AND DeveloperName = 'T_M'
            ]) {
                tmRecordTypeIds.add(rt.Id);
            }
            
            
            //  Only process when important fields changed
            if (isAccountChanged || isStageChanged) {
                
                // If Stage changed OR updated Opp belongs to an account
                if (oNew.AccountId != null) {
                    accIds.add(oNew.AccountId);
                }
                
                // If Opportunity moved account, also include old account
                if (isAccountChanged && oOld.AccountId != null) {
                    accIds.add(oOld.AccountId);
                }
            }
            
            if (isStageChanged && (oNew.StageName == 'Closed Won' || oNew.StageName == 'Closed Lost') && oNew.RecordType.Name != null /*&& oNew.RecordType.Name.equalsIgnoreCase('Turnkey_and_Hardware')*/) {
                isCLosedIds.add(oNew.Id);
            }
            if (oOld.Amount != oNew.Amount && tmRecordTypeIds != null &&
                tmRecordTypeIds.contains(oNew.RecordTypeId)) {
                   // isFromOpp = true;
                    isRLIOpp.add(oNew.Id);
                }
            // Boolean isFinancialChanged = isCurrencyChanged || isAmountChanged;
            
            if (isCurrencyChanged && oNew.CurrencyIsoCode != null && !processedOpportunityIds.contains(oNew.Id)) {
                
                // Even if currency not changed, we still need old currency for recalculation
                oppOldCurrencyMap.put(oNew.Id, oOld.CurrencyIsoCode);
                processedOpportunityIds.add(oNew.Id);
            }
            
            // Queue Currency Conversion
            if (!oppOldCurrencyMap.isEmpty() && !currencyJobQueued && !System.isQueueable()) {
                currencyJobQueued = true;
                System.enqueueJob(new OpportunityCurrencyQueue(oppOldCurrencyMap));
            }
            
        }
        // Queue Currency Conversion
        if(!oppOldCurrencyMap.isEmpty() && !currencyJobQueued && !System.isQueueable()){
            currencyJobQueued = true;
            System.enqueueJob(new OpportunityCurrencyQueue(oppOldCurrencyMap));
        }
        //System.debug('isRLIOpp: '+isRLIOpp);
        /*if (!isRLIOpp.isEmpty() && isFromOpp) {
            System.enqueueJob(new RLIEmailQueueable(isRLIOpp, isFromOpp));
        }*/
        if (!isRLIOpp.isEmpty() && !rliJobQueued) {
            rliJobQueued = true;
            System.enqueueJob(new RLIEmailQueueable(isRLIOpp, true));
        }
        lockRevenueProjection(isCLosedIds);
        enqueueJob(accIds);
    }
    
    public class OpportunityCurrencyQueue implements Queueable {
        
        private Map<Id, String> oppOldCurrencyMap;
        
        public OpportunityCurrencyQueue(Map<Id, String> oppOldCurrencyMap){
            this.oppOldCurrencyMap = oppOldCurrencyMap;
        }
        
        public void execute(QueueableContext context){
            OpportunityHandlerServices.handleOpportunityCurrencyChange(oppOldCurrencyMap);
        }
    }
    
    public static void afterDelete(List<Opportunity> oldList) {
        Set<Id> accIds = collectAccountIds(oldList);
        enqueueJob(accIds);
        Set<Id> parentOppIds = new Set<Id>();
        for (Opportunity oNew : oldList) {
            if (oNew.Parent_Opportunity__c != null) {
                parentOppIds.add(oNew.Parent_Opportunity__c);
            }
        }
        System.debug('parentOppIds: '+parentOppIds);
        if (!parentOppIds.isEmpty()) {
            //OpportunityHandlerServices.rollupAmount(parentOppIds);
        }
    }
    
    public static void afterUndelete(List<Opportunity> newList) {
        Set<Id> accIds = collectAccountIds(newList);
        enqueueJob(accIds);
        Set<Id> parentOppIds = new Set<Id>();
        for (Opportunity oNew : newList) {
            if (oNew.Parent_Opportunity__c != null) {
                parentOppIds.add(oNew.Parent_Opportunity__c);
            }
        }
        System.debug('parentOppIds: '+parentOppIds);
        if (!parentOppIds.isEmpty()) {
            //OpportunityHandlerServices.rollupAmount(parentOppIds);
        }
    }
    
    // ============================
    // Helper Methods
    // ============================
    
    private static Set<Id> collectAccountIds(List<Opportunity> oppList) {
        Set<Id> accountIds = new Set<Id>();
        if (oppList == null) return accountIds;
        
        for (Opportunity o : oppList) {
            if (o.AccountId != null) {
                accountIds.add(o.AccountId);
            }
        }
        return accountIds;
    }
    
    private static void enqueueJob(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;
        
        // Queueable inside Queueable + multiple enqueue
        if (System.isQueueable()) return;
        if (Limits.getQueueableJobs() > 0) return;
        if (jobQueued) return;
        
        jobQueued = true;
        
        System.enqueueJob(new AccountStatusQueueable(new List<Id>(accountIds)));
    }
    
    public static void lockRevenueProjection(Set<Id> oppIds) {
        
        if (oppIds == null || oppIds.isEmpty()) {
            return;
        }
        
        try {
            
            List<Revenue_Projection__c> rpList = [
                SELECT Id, Projection_Status__c
                FROM Revenue_Projection__c
                WHERE Opportunity__c IN :oppIds
            ];
            
            if (rpList.isEmpty()) {
                return;
            }
            
            for (Revenue_Projection__c rp : rpList) {
                rp.Projection_Status__c = 'Locked';
            }
            
            update rpList;
            
        } catch (DmlException dmlEx) {
            
            System.debug('Revenue Projection Lock DML Error: ' + dmlEx.getMessage());
            System.debug('Line Number: ' + dmlEx.getLineNumber());
            
        } catch (Exception ex) {
            
            System.debug('Revenue Projection Lock General Error: ' + ex.getMessage());
        }
    }
}