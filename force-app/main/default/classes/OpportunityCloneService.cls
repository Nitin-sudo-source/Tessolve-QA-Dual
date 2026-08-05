public with sharing class OpportunityCloneService {
    
    private static final String RLI_OBJECT = 'Resource_Line_Item__c';
    private static final Set<String> REVENUE_PROJECTION_MODELS =
        new Set<String>{'SoC_Services','IP','Pro_Video','ASIC'};
                    
                    /***********************************************************************
* Load Clone Wizard
***********************************************************************/
                    public static OpportunityCloneWrapper loadClonePage(Id opportunityId) {
                        
                        OpportunityCloneWrapper wrapper = new OpportunityCloneWrapper();
                        
                        try {
                            
                            Opportunity sourceOpportunity = [
                                SELECT
                                Id,
                                Name,
                                AccountId,
                                Account.Name,
                                OwnerId,
                                Owner.Name,
                                RecordTypeId,
                                RecordType.Name,
                                RecordType.DeveloperName,
                                StageName,
                                CloseDate,
                                Probability,
                                CurrencyIsoCode,
                                Type,
                                LeadSource,
                                Description,
                                Amount,
                                Engagement_Model__c,
                                Sub_Business_Unit__c,
                                Technical_Owner__c,
                                Technical_Owner__r.Name,
                                Markets__c,
                                Application__c,
                                TCV_in_USD__c,
                                Annual_Contract_Value_ACV_In_USD__c
                                
                                FROM Opportunity
                                WHERE Id = :opportunityId
                                LIMIT 1
                            ];
                            
                            /******************************
* Source Opportunity
******************************/
                            wrapper.sourceOpportunity = sourceOpportunity;
                            
                            /******************************
* Clone Opportunity
******************************/
                            Opportunity cloneOpp = sourceOpportunity.clone(false, false, false, false);
                            
                            cloneOpp.Name = sourceOpportunity.Name + ' (Copy)';
                            
                            // Optional Business Rule
                            // cloneOpp.StageName = 'Prequalified';
                            
                            wrapper.cloneOpportunity = cloneOpp;
                            
                            //wrapper.engagementModel = (String)sourceOpportunity.get('Engagement_Model__c');
                            
                            wrapper.showRevenueLineItems =   wrapper.engagementModel == 'T_M';
                            
                            wrapper.showRevenueProjectionPopup =  REVENUE_PROJECTION_MODELS.contains(wrapper.engagementModel);
                            
                            wrapper.recordTypes = getRecordTypes();
                            
                            wrapper.stageOptions = getStageValues();
                            
                            wrapper.relatedCounts =
                                getRelatedCounts(opportunityId);
                            
                            wrapper.success = true;
                            
                        }
                        catch (Exception ex) {
                            
                            wrapper.success = false;
                            
                            wrapper.message = ex.getMessage();
                            
                        }
                        
                        return wrapper;
                        
                    }
    
    /***********************************************************************
* Opportunity Record Types
***********************************************************************/
    public static List<OpportunityCloneWrapper.RecordTypeOption> getRecordTypes() {
        
        List<OpportunityCloneWrapper.RecordTypeOption> options =
            new List<OpportunityCloneWrapper.RecordTypeOption>();
        
        for (RecordType rt : [
            
            SELECT
            Id,
            Name,
            DeveloperName
            
            FROM RecordType
            
            WHERE
            SObjectType = 'Opportunity'
            AND IsActive = TRUE
            
            ORDER BY Name
            
        ]) {
            
            OpportunityCloneWrapper.RecordTypeOption option =
                new OpportunityCloneWrapper.RecordTypeOption();
            
            option.value = rt.Id;
            option.label = rt.Name;
            option.developerName = rt.DeveloperName;
            
            options.add(option);
            
        }
        
        return options;
        
    }
    
    /***********************************************************************
* Stage Picklist
***********************************************************************/
    public static List<OpportunityCloneWrapper.PicklistOption> getStageValues() {
        
        List<OpportunityCloneWrapper.PicklistOption> options =
            new List<OpportunityCloneWrapper.PicklistOption>();
        
        Schema.DescribeFieldResult describe = Opportunity.StageName.getDescribe();
        
        for (Schema.PicklistEntry pe : describe.getPicklistValues()) {
            
            OpportunityCloneWrapper.PicklistOption option =
                new OpportunityCloneWrapper.PicklistOption();
            
            option.label = pe.getLabel();
            option.value = pe.getValue();
            
            options.add(option);
            
        }
        
        return options;
        
    }
    
    /***********************************************************************
* User Lookup
***********************************************************************/
    public static List<User> searchUsers(String keyword) {
        
        if (String.isBlank(keyword)) {
            keyword = '';
        }
        
        return [
            
            SELECT
            Id,
            Name,
            Email
            
            FROM User
            
            WHERE
            IsActive = TRUE
            AND Name LIKE :('%' + keyword + '%')
            
            ORDER BY Name
            
            LIMIT 20
            
        ];
        
    }
    
    /***********************************************************************
* Related Record Counts
***********************************************************************/
    public static OpportunityCloneWrapper.RelatedCounts getRelatedCounts(
        Id opportunityId
    ) {
        
        OpportunityCloneWrapper.RelatedCounts counts =
            new OpportunityCloneWrapper.RelatedCounts();
        
        counts.files = [
            
            SELECT COUNT()
            
            FROM ContentDocumentLink
            
            WHERE LinkedEntityId = :opportunityId
            
        ];
        
        counts.contactRoles = [
            
            SELECT COUNT()
            
            FROM OpportunityContactRole
            
            WHERE OpportunityId = :opportunityId
            
        ];
        
        List<OpportunityTeamMember> sizeofTeamMember = [
            
            SELECT ID
            
            FROM OpportunityTeamMember
            
            WHERE OpportunityId = :opportunityId
            
        ];
        
        counts.opportunityTeam = sizeofTeamMember.size();
        
        
        
        // Replace with your Revenue Line Item object
        List<Resource_Line_Item__c> sizeofrevenueLineItems  = [
            
            SELECT ID
            
            FROM Resource_Line_Item__c
            
            WHERE Related_Opportunity__c = :opportunityId
            
        ];
        
        counts.revenueLineItems = sizeofrevenueLineItems.size();
        
        // Replace with your Revenue Projection object
        counts.revenueProjections = [
            
            SELECT COUNT()
            
            FROM Revenue_Projection__c
            
            WHERE Opportunity__c = :opportunityId
            
        ];
        
        return counts;
        
    }
    
    /***********************************************************************
* Clone Opportunity
***********************************************************************/
    public static OpportunityCloneWrapper.CloneResponse cloneOpportunity(OpportunityCloneWrapper.CloneRequest request) {
        
        OpportunityCloneWrapper.CloneResponse response =  new OpportunityCloneWrapper.CloneResponse();
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            
           /* if(request == null){
                throw new AuraHandledException('Clone request cannot be null.');
            }
            
            if(request.cloneOpportunity == null){
                throw new AuraHandledException('Clone Opportunity is required.');
            }
            
            if(request.sourceOpportunityId == null){
                throw new AuraHandledException('Source Opportunity Id is required.');
            }
            
            Opportunity clonedOpportunity = createOpportunity(request.cloneOpportunity);
            
            String engagementModel = (String)clonedOpportunity.get('Engagement_Model__c');
            System.debug('engagementModel: '+engagementModel);
*/
            
            /*
* T&M
*/
            /*if (engagementModel == 'T_M') {
                
                if (request.cloneConfiguration.cloneRevenueLineItems) {
                    
                    cloneChildRecords(
                        'Resource_Line_Item__c',
                        'Related_Opportunity__c',
                        request.sourceOpportunityId,
                        clonedOpportunity.Id,
                        new Set<String>{ 'Id' },
                        new Map<String,Object>{
                            'Status__c' => 'Resource To Be Identified',
                                'Resource_Name__c' => null
                                }
                    );
                }
                
            } 
            if (request.cloneConfiguration.cloneOpportunityTeam) {
                
                cloneChildRecords(
                    'OpportunityTeamMember',
                    'OpportunityId',
                    request.sourceOpportunityId,
                    clonedOpportunity.Id,
                    new Set<String>{ 'Id' },
                    null
                );
            }
            
            if (request.cloneConfiguration.cloneContactRoles) {
                
                cloneChildRecords(
                    'OpportunityContactRole',
                    'OpportunityId',
                    request.sourceOpportunityId,
                    clonedOpportunity.Id,
                    new Set<String>{ 'Id' },
                    null
                );
            }*/
            
            
         /*   if(request.cloneConfiguration.cloneFiles){
                
                cloneFiles(
                    request.sourceOpportunityId,
                    clonedOpportunity.Id
                );
                
            }*/
          
         
            
            //response.showRevenueProjectionPopup = REVENUE_PROJECTION_MODELS.contains(engagementModel);
            System.debug('request: '+ request);
            System.debug('request.cloneOpportunity: '+ request.cloneOpportunity);
            request.cloneOpportunity.StageName = 'Prequalified';
            Opportunity clonedOpportunity = createOpportunity(request.cloneOpportunity);
            System.debug('clonedOpportunity: '+clonedOpportunity);
            response.showRevenueProjectionPopup = true;
            
            response.success = true;
            response.message = 'Opportunity cloned successfully.';
            response.clonedOpportunityId = clonedOpportunity.Id;
            response.clonedOpportunityName = clonedOpportunity.Name;
            //response.engagementModel = engagementModel;
            //response.showRevenueLineItems = engagementModel == 'T&M';
            
        }
        catch(Exception ex){
            
            Database.rollback(sp);
            
            response.success = false;
            response.message = ex.getMessage();
            response.errors.add(ex.getMessage());
            
        }
        
        return response;
        
    }
    
    
    /***********************************************************************
* Create Opportunity
***********************************************************************/
    private static Opportunity createOpportunity(Opportunity opportunityToClone) {
        
        if (!Schema.sObjectType.Opportunity.isCreateable()) {
            
            throw new AuraHandledException(
                'You do not have permission to create Opportunity.'
            );
            
        }
        
        Opportunity newOpportunity = new Opportunity();
        
        // Standard Fields
        newOpportunity.Name = opportunityToClone.Name;
        newOpportunity.AccountId = opportunityToClone.AccountId;
        newOpportunity.OwnerId = opportunityToClone.OwnerId;
        newOpportunity.RecordTypeId = opportunityToClone.RecordTypeId;
        newOpportunity.StageName = opportunityToClone.StageName;
        newOpportunity.CloseDate = opportunityToClone.CloseDate;
        newOpportunity.Probability = opportunityToClone.Probability;
        newOpportunity.Amount = opportunityToClone.Amount;
        newOpportunity.CurrencyIsoCode = opportunityToClone.CurrencyIsoCode;
        newOpportunity.LeadSource = opportunityToClone.LeadSource;
        
        // Custom Fields
        newOpportunity.Engagement_Model__c = opportunityToClone.Engagement_Model__c;
       // newOpportunity.Sub_Business_Unit__c = opportunityToClone.Sub_Business_Unit__c;
        newOpportunity.Markets__c = opportunityToClone.Markets__c;
        newOpportunity.Application__c = opportunityToClone.Application__c;
        newOpportunity.Technical_Owner__c = opportunityToClone.Technical_Owner__c;
        newOpportunity.TCV_in_USD__c = opportunityToClone.TCV_in_USD__c;
        
        // Remove fields the user cannot create
        SObjectAccessDecision accessDecision =
            Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ newOpportunity }
            );
        
        newOpportunity = (Opportunity) accessDecision.getRecords()[0];
        
        insert newOpportunity;
        
        System.debug('newOpportunity: ' + newOpportunity);
        
        return newOpportunity;
    }
    
    
    
    /**************************************************************************************************
* Clone Files
**************************************************************************************************/
    private static void cloneFiles(
        Id sourceOpportunityId,
        Id clonedOpportunityId
    ) {
        
        List<ContentDocumentLink> sourceLinks = [
            
            SELECT
            ContentDocumentId,
            ShareType,
            Visibility
            
            FROM ContentDocumentLink
            
            WHERE LinkedEntityId = :sourceOpportunityId
            
        ];
        
        if(sourceLinks.isEmpty()){
            return;
        }
        
        List<ContentDocumentLink> clonedLinks =
            new List<ContentDocumentLink>();
        
        Set<Id> documentIds = new Set<Id>();
        
        for(ContentDocumentLink link : sourceLinks){
            documentIds.add(link.ContentDocumentId);
        }
        
        // Prevent duplicate links
        for(ContentDocumentLink existing : [
            
            SELECT ContentDocumentId
            
            FROM ContentDocumentLink
            
            WHERE LinkedEntityId = :clonedOpportunityId
            AND ContentDocumentId IN :documentIds
            
        ]){
            
            documentIds.remove(existing.ContentDocumentId);
            
        }
        
        for(ContentDocumentLink link : sourceLinks){
            
            if(!documentIds.contains(link.ContentDocumentId)){
                continue;
            }
            
            clonedLinks.add(new ContentDocumentLink(
                
                LinkedEntityId = clonedOpportunityId,
                
                ContentDocumentId = link.ContentDocumentId,
                
                ShareType = link.ShareType,
                
                Visibility = link.Visibility
                
            ));
            
        }
        
        if(!clonedLinks.isEmpty()){
            
            insert clonedLinks;
            
        }
        
    }
    
    
    /**************************************************************************************************
* Generic Child Record Clone
**************************************************************************************************/
    private static void cloneChildRecords(
        String objectApiName,
        String parentLookupField,
        Id sourceParentId,
        Id targetParentId,
        Set<String> excludedFields,
        Map<String, Object> overrideValues
    ) {
        
        Schema.SObjectType sObjectType =
            Schema.getGlobalDescribe().get(objectApiName);
        
        if (sObjectType == null) {
            return;
        }
        
        Map<String, Schema.SObjectField> fieldMap =
            sObjectType.getDescribe().fields.getMap();
        
        List<String> selectFields = new List<String>();
        
        for (String fieldName : fieldMap.keySet()) {
            
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldName).getDescribe();
            
            // Skip unsupported fields
            if (fieldDescribe.isCalculated()) continue;
            if (fieldDescribe.isAutoNumber()) continue;
            
            // Skip excluded fields
            if (excludedFields != null && excludedFields.contains(fieldName)) {
                continue;
            }
            
            selectFields.add(fieldName);
        }
        
        if (selectFields.isEmpty()) {
            return;
        }
        
        String soql =
            'SELECT ' +
            String.join(selectFields, ',') +
            ' FROM ' + objectApiName +
            ' WHERE ' + parentLookupField + ' = :sourceParentId';
        
        List<SObject> sourceRecords = Database.query(soql);
        
        if (sourceRecords.isEmpty()) {
            return;
        }
        
        List<SObject> clonedRecords = new List<SObject>();
        
        for (SObject sourceRecord : sourceRecords) {
            
            SObject cloneRecord = sourceRecord.clone(
                false,  // preserveId
                false,  // isDeepClone
                false,  // preserveReadonlyTimestamps
                false   // preserveAutonumber
            );
            
            // Assign new parent
            cloneRecord.put(parentLookupField, targetParentId);
            
            // Apply override values
            if (overrideValues != null) {
                for (String fieldName : overrideValues.keySet()) {
                    cloneRecord.put(fieldName, overrideValues.get(fieldName));
                }
            }
            
            clonedRecords.add(cloneRecord);
        }
        
        if (!clonedRecords.isEmpty()) {
            insert clonedRecords;
        }
    }
    
}