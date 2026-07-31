public class RevenueProjectionItemHelper {
    /* ================= INSERT ================= */
    
    public static void handleAfterInsert(List<Revenue_Projection__c> newList){
        Set<Id> oppIds = new Set<Id>();
        for(Revenue_Projection__c rli : newList){
            if(rli.Opportunity__c != null){
                oppIds.add(rli.Opportunity__c);
            }
        }
        RevenueProjectionItemRollup.rollupData(oppIds);
    }
    
    
    /* ================= UPDATE ================= */
    
    public static void handleAfterUpdate(List<Revenue_Projection__c> newList, Map<Id, Revenue_Projection__c> oldMap){
        Set<Id> oppIds = new Set<Id>();
        for(Revenue_Projection__c rli : newList){
            Revenue_Projection__c oldRec = oldMap.get(rli.Id);
            
            // If lookup changed OR value changed (optional condition)
            if(rli.Opportunity__c != oldRec.Opportunity__c){
                if(rli.Opportunity__c != null)
                    oppIds.add(rli.Opportunity__c);
                if(oldRec.Opportunity__c != null)
                    oppIds.add(oldRec.Opportunity__c);
            }else if(rli.Opportunity__c != null){
                oppIds.add(rli.Opportunity__c);
            }
        }
        RevenueProjectionItemRollup.rollupData(oppIds);
    }
    
    
    /* ================= DELETE ================= */
    
    public static void handleAfterDelete(List<Revenue_Projection__c> oldList){
        Set<Id> oppIds = new Set<Id>();
        for(Revenue_Projection__c rli : oldList){
            if(rli.Opportunity__c != null){
                oppIds.add(rli.Opportunity__c);
            }
        }
        RevenueProjectionItemRollup.rollupData(oppIds);
    }
    
    
    /* ================= UNDELETE ================= */
    
    public static void handleAfterUndelete(List<Revenue_Projection__c> newList){
        Set<Id> oppIds = new Set<Id>();
        
        for(Revenue_Projection__c rli : newList){
            if(rli.Opportunity__c != null){
                oppIds.add(rli.Opportunity__c);
            }
        }
        
        RevenueProjectionItemRollup.rollupData(oppIds);
    }
}