trigger Revenue_Projection_Trigger on Revenue_Projection__c (after insert, after update, after delete, after undelete) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            RevenueProjectionItemHelper.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            RevenueProjectionItemHelper.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        
        if (Trigger.isDelete) {
            RevenueProjectionItemHelper.handleAfterDelete(Trigger.old);
        }
        
        if (Trigger.isUndelete) {
            RevenueProjectionItemHelper.handleAfterUndelete(Trigger.new);
        }
    }
    
    
}