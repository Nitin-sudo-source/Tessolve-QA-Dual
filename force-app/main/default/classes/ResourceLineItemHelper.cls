public class ResourceLineItemHelper {
    /* ================= INSERT ================= */
    
    public static void handleAfterInsert(List<Resource_Line_Item__c> newList){
        Set<Id> oppIds = new Set<Id>();
        Set<Id> emailOppIds  = new Set<Id>();
        for(Resource_Line_Item__c rli : newList){
            if(rli.Related_Opportunity__c != null){
                oppIds.add(rli.Related_Opportunity__c);
            }
            if( rli.Related_Opportunity__c != null && rli.Status__c != null && rli.Status__c.equalsIgnoreCase('Lost')){
                emailOppIds.add(rli.Related_Opportunity__c);
            }
            
        }
        ResourceLineItemRollup.rollupData(oppIds);
        if (!emailOppIds.isEmpty()) {
            Boolean isFromOpp = false;
            System.enqueueJob(new RLIEmailQueueable(emailOppIds, isFromOpp));
        }
    }
    
    
    /* ================= UPDATE ================= */
    
    public static void handleAfterUpdate(
        List<Resource_Line_Item__c> newList,
        Map<Id, Resource_Line_Item__c> oldMap
    ){
        Set<Id> rollupOppIds = new Set<Id>();
        Set<Id> emailOppIds  = new Set<Id>();
        
        for (Resource_Line_Item__c rli : newList) {
            
            Resource_Line_Item__c oldRec = oldMap.get(rli.Id);
            
            // =========================
            // ✅ ROLLUP LOGIC (UNCHANGED)
            // =========================
            if (rli.Related_Opportunity__c != oldRec.Related_Opportunity__c && rli.Related_Opportunity__c != null ) {
                
                if (rli.Related_Opportunity__c != null)
                    rollupOppIds.add(rli.Related_Opportunity__c);
                
            } else if (rli.Related_Opportunity__c != null) {
                rollupOppIds.add(rli.Related_Opportunity__c);
            }
            if(oldRec.Status__c != rli.Status__c && rli.Status__c != null && rli.Status__c.equalsIgnoreCase('Lost') 
               ||
               (
                   rli.Status__c != null &&
                   rli.Status__c.equalsIgnoreCase('Resource Confirmed') &&
                   oldRec.Number_of_Resources__c != rli.Number_of_Resources__c
               )){
                   emailOppIds.add(rli.Related_Opportunity__c);
               }
            
        }
        
        if (!rollupOppIds.isEmpty()) {
            ResourceLineItemRollup.rollupData(rollupOppIds);
        }
        
        if (!emailOppIds.isEmpty()) {
            Boolean isFromOpp = false;
            System.enqueueJob(new RLIEmailQueueable(emailOppIds, isFromOpp));
        }
    }
    
    
    /* ================= DELETE ================= */
    
    public static void handleAfterDelete(List<Resource_Line_Item__c> oldList){
        Set<Id> oppIds = new Set<Id>();
        for(Resource_Line_Item__c rli : oldList){
            if(rli.Related_Opportunity__c != null){
                oppIds.add(rli.Related_Opportunity__c);
            }
        }
        ResourceLineItemRollup.rollupData(oppIds);
    }
    
    
    /* ================= UNDELETE ================= */
    
    public static void handleAfterUndelete(List<Resource_Line_Item__c> newList){
        Set<Id> oppIds = new Set<Id>();
        
        for(Resource_Line_Item__c rli : newList){
            if(rli.Related_Opportunity__c != null){
                oppIds.add(rli.Related_Opportunity__c);
            }
        }
        
        ResourceLineItemRollup.rollupData(oppIds);
    }
    
}