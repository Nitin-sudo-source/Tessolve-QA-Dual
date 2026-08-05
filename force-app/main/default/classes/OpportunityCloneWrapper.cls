public with sharing class OpportunityCloneWrapper {
    
    /*==========================================================
* Opportunity Information
==========================================================*/
    
    @AuraEnabled
    public Opportunity sourceOpportunity;
    
    @AuraEnabled
    public Opportunity cloneOpportunity;
    
    /*==========================================================
* Clone Configuration
==========================================================*/
    
    @AuraEnabled
    public CloneConfiguration cloneConfiguration;
    
    /*==========================================================
* Related Record Counts
==========================================================*/
    
    @AuraEnabled
    public RelatedCounts relatedCounts;
    
    /*==========================================================
* UI Data
==========================================================*/
    
    @AuraEnabled
    public List<RecordTypeOption> recordTypes;
    
    @AuraEnabled
    public List<PicklistOption> stageOptions;
    
    @AuraEnabled
    public List<PicklistOption> ownerOptions;
    
    /*==========================================================
* Page Configuration
==========================================================*/
    
    @AuraEnabled
    public Boolean success;
    
    @AuraEnabled
    public String message;
    
    @AuraEnabled
    public Boolean showRevenueProjectionPopup;
    
    @AuraEnabled
    public Boolean showRevenueLineItems;
    
    @AuraEnabled
    public String engagementModel;
    
    public OpportunityCloneWrapper() {
        
        sourceOpportunity = new Opportunity();
        
        cloneOpportunity = new Opportunity();
        
        cloneConfiguration = new CloneConfiguration();
        
        relatedCounts = new RelatedCounts();
        
        recordTypes = new List<RecordTypeOption>();
        
        stageOptions = new List<PicklistOption>();
        
        ownerOptions = new List<PicklistOption>();
        
        success = true;
        
        message = '';
    }
    
    /************************************************************
* Clone Configuration
************************************************************/
    public class CloneConfiguration {
        
        @AuraEnabled
        public Boolean cloneRevenueLineItems = true;
        
        @AuraEnabled
        public Boolean cloneRevenueProjection = false;
        
        @AuraEnabled
        public Boolean cloneProducts = true;
        
        @AuraEnabled
        public Boolean cloneFiles = true;
        
        @AuraEnabled
        public Boolean cloneOpportunityTeam = true;
        
        @AuraEnabled
        public Boolean cloneContactRoles = true;
        
        @AuraEnabled
        public Boolean cloneNotes = false;
        
        @AuraEnabled
        public Boolean cloneTasks = false;
        
        @AuraEnabled
        public Boolean cloneAttachments = true;
    }
    
    /************************************************************
* Related Counts
************************************************************/
    public class RelatedCounts {
        
        @AuraEnabled
        public Integer revenueLineItems = 0;
        
        @AuraEnabled
        public Integer revenueProjections = 0;
        
        @AuraEnabled
        public Integer products = 0;
        
        @AuraEnabled
        public Integer files = 0;
        
        @AuraEnabled
        public Integer opportunityTeam = 0;
        
        @AuraEnabled
        public Integer contactRoles = 0;
        
        @AuraEnabled
        public Integer notes = 0;
        
        @AuraEnabled
        public Integer tasks = 0;
        
        @AuraEnabled
        public Integer attachments = 0;
    }
    
    /************************************************************
* Record Type
************************************************************/
    public class RecordTypeOption {
        
        @AuraEnabled
        public Id value;
        
        @AuraEnabled
        public String label;
        
        @AuraEnabled
        public String developerName;
        
        @AuraEnabled
        public Boolean selected;
    }
    
    /************************************************************
* Generic Picklist
************************************************************/
    public class PicklistOption {
        
        @AuraEnabled
        public String label;
        
        @AuraEnabled
        public String value;
    }
    
    /************************************************************
* Clone Request
************************************************************/
    public class CloneRequest {
        
        @AuraEnabled
        public Opportunity cloneOpportunity { get; set; }
        
        @AuraEnabled
        public CloneConfiguration cloneConfiguration { get; set; }
        
        @AuraEnabled
        public Id sourceOpportunityId { get; set; }
        
        public CloneRequest() {
            cloneOpportunity = new Opportunity();
            cloneConfiguration = new CloneConfiguration();
        }
    }
    /************************************************************
* Clone Response
************************************************************/
    public class CloneResponse {
        
        @AuraEnabled
        public Boolean success;
        
        @AuraEnabled
        public String message;
        
        @AuraEnabled
        public Id clonedOpportunityId;
        
        @AuraEnabled
        public String clonedOpportunityName;
        
        @AuraEnabled
        public Boolean showRevenueProjectionPopup;
        
        @AuraEnabled
        public Boolean showRevenueLineItems;
        
        @AuraEnabled
        public String engagementModel;
        
        @AuraEnabled
        public List<String> errors;
        
        public CloneResponse() {
            
            success = true;
            
            errors = new List<String>();
            
        }
    }
    
}