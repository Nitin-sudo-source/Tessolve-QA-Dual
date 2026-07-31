trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update, after delete, after undelete) {
    /*if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            System.debug('Before Insert Fired');
            OpportunityHandler.beforeInsert(Trigger.new);
        }
}*/
    if (Trigger.isBefore) {
        
        if (Trigger.isInsert) {
            OpportunityAccountStatusHandler.beforeInsert(Trigger.new);
        }
        
        if (Trigger.isUpdate) {
            OpportunityAccountStatusHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    if (Trigger.isAfter) {
        
        if (Trigger.isInsert) {
            OpportunityAccountStatusHandler.afterInsert(Trigger.new);
        }
        
        if (Trigger.isUpdate) {
            OpportunityAccountStatusHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
        
        if (Trigger.isDelete) {
            OpportunityAccountStatusHandler.afterDelete(Trigger.old);
        }
        
        if (Trigger.isUndelete) {
            OpportunityAccountStatusHandler.afterUndelete(Trigger.new);
        }
    }
}