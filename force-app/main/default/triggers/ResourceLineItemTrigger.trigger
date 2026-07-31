trigger ResourceLineItemTrigger on Resource_Line_Item__c (after insert, after update, after delete, after undelete) {
    
    Set<Id> oppIds = new Set<Id>();
    
    if(Trigger.isInsert || Trigger.isUpdate){
        for(Resource_Line_Item__c rli : Trigger.new){
            if(rli.Related_Opportunity__c != null)
                oppIds.add(rli.Related_Opportunity__c);
        }
        if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                ResourceLineItemHelper.handleAfterInsert(Trigger.new);
            }
            if (Trigger.isUpdate) {
                ResourceLineItemHelper.handleAfterUpdate(Trigger.new, Trigger.oldMap);
            }
        }
    }
    
    if(Trigger.isDelete){
        for(Resource_Line_Item__c rli : Trigger.old){
            if(rli.Related_Opportunity__c != null)
                oppIds.add(rli.Related_Opportunity__c);
        }
        if (Trigger.isDelete) {
            ResourceLineItemHelper.handleAfterDelete(Trigger.old);
        }
    }
    
    if (Trigger.isUndelete) {
        ResourceLineItemHelper.handleAfterUndelete(Trigger.new);
    }
    
    RevenueProjectionEngine.recalcFromResourceLines(oppIds);
    
}