trigger PaymentMilestoneTrigger on Payment_Milestone__c (after insert, after update, after delete) {
    
    Set<Id> oppIds = new Set<Id>();

    if(Trigger.isInsert || Trigger.isUpdate){
        for(Payment_Milestone__c ms : Trigger.new){
            if(ms.Opportunity__c != null)
                oppIds.add(ms.Opportunity__c);
        }
    }

    if(Trigger.isDelete){
        for(Payment_Milestone__c ms : Trigger.old){
            if(ms.Opportunity__c != null)
                oppIds.add(ms.Opportunity__c);
        }
    }

    //RevenueProjectionEngine.recalcFromMilestones(oppIds);

}