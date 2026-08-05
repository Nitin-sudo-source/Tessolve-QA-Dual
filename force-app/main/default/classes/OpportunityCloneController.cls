public with sharing class OpportunityCloneController {
    
    /**
* Load Clone Wizard
*/
    @AuraEnabled(cacheable=true)
    public static OpportunityCloneWrapper loadClonePage(Id opportunityId) {
        return OpportunityCloneService.loadClonePage(opportunityId);
    }
    
    /**
* Clone Opportunity
*/
    @AuraEnabled
    public static OpportunityCloneWrapper.CloneResponse cloneOpportunity(
        OpportunityCloneWrapper.CloneRequest request
    ) {
        return OpportunityCloneService.cloneOpportunity(request);
    }
    
    /**
* Get Stage Picklist
*/
    @AuraEnabled(cacheable=true)
    public static List<OpportunityCloneWrapper.PicklistOption> getStageValues() {
        return OpportunityCloneService.getStageValues();
    }
    
    /**
* Get Opportunity Record Types
*/
    @AuraEnabled(cacheable=true)
    public static List<OpportunityCloneWrapper.RecordTypeOption> getRecordTypes() {
        return OpportunityCloneService.getRecordTypes();
    }
    
    /**
* Search Users (Owner / Technical Owner)
*/
    @AuraEnabled(cacheable=true)
    public static List<User> searchUsers(String searchText) {
        return OpportunityCloneService.searchUsers(searchText);
    }
    
    /**
* Get Related Record Counts
*/
    @AuraEnabled(cacheable=true)
    public static OpportunityCloneWrapper.RelatedCounts getRelatedCounts(Id opportunityId) {
        return OpportunityCloneService.getRelatedCounts(opportunityId);
    }
}