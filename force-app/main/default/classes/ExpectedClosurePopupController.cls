public with sharing class ExpectedClosurePopupController {
    
    @AuraEnabled
    public static List<OpportunityWrapper> getPendingOpportunities() {
        
        List<Opportunity> opportunities = [
            SELECT Id,
            Name,
            AccountId,
            Account.Name,
            StageName,
            CloseDate,
            Expected_Close_Date__c,
            OwnerId,
            ACV_in_Opportunity_Currency__c,
            TCV_in_Opportunity_Currency__c,
            Opportunity_Id__c,
            Owner.Name
            FROM Opportunity
            WHERE OwnerId = :UserInfo.getUserId()
            AND IsClosed = FALSE
            AND Expected_Close_Date__c = NULL
            ORDER BY CloseDate ASC
            LIMIT 100
        ];
        
        List<OpportunityWrapper> results = new List<OpportunityWrapper>();
        
        for (Opportunity opp : opportunities) {
            OpportunityWrapper wrapper = new OpportunityWrapper();
            
            wrapper.opportunityId = opp.Id;
            wrapper.oppIdFormat = opp.Opportunity_Id__c;
            wrapper.opportunityName = opp.Name;
            wrapper.accountName = opp.Account != null
                ? opp.Account.Name
                : '';
            wrapper.stageName = opp.StageName;
            wrapper.closeDate = opp.CloseDate;
            wrapper.expectedClosureDate = opp.Expected_Close_Date__c;
            wrapper.ownerName = opp.Owner.Name;
            wrapper.formattedAcv = opp.ACV_in_Opportunity_Currency__c != null
                ? String.valueOf(opp.ACV_in_Opportunity_Currency__c.setScale(2, RoundingMode.HALF_UP))
                : '0.00';
            
            wrapper.formattedTcv = opp.TCV_in_Opportunity_Currency__c != null
                ? String.valueOf(opp.TCV_in_Opportunity_Currency__c.setScale(2, RoundingMode.HALF_UP))
                : '0.00';
            
            results.add(wrapper);
        }
        
        return results;
    }
    
    @AuraEnabled
    public static SaveResponse saveExpectedClosureDates(List<OpportunityWrapper> OpportunityWrapperUpdates) {
        System.debug('OpportunityWrapperUpdates: '+OpportunityWrapperUpdates);
        
        SaveResponse response = new SaveResponse();
        
        
        
        if (OpportunityWrapperUpdates == null || OpportunityWrapperUpdates.isEmpty()) {
            response.success = false;
            response.message = 'No changes were found to save.';
            return response;
        }
        
        try {
            
            Map<Id, Date> dateMap = new Map<Id, Date>();
            Map<Id, OpportunityWrapper> wrapperMap = new Map<Id, OpportunityWrapper>();

            
            for (OpportunityWrapper row : OpportunityWrapperUpdates) {
                System.debug('row: '+ row  );
                System.debug('row.expectedClosureDate: '+ row.expectedClosureDate);
                
                if (row.opportunityId == null) {
                    continue;
                }
                
                if (row.expectedClosureDate == null) {
                    response.success = false;
                    response.message = 'Please select an Expected Closure Date for all modified opportunities.';
                    return response;
                }
                
                dateMap.put(row.opportunityId, row.expectedClosureDate);
                wrapperMap.put(row.opportunityId, row);
            }
            
            List<Opportunity> opportunities = [
                SELECT Id,
                Expected_Close_Date__c
                FROM Opportunity
                WHERE Id IN :dateMap.keySet()
                FOR UPDATE
            ];
            
            for (Opportunity opp : opportunities) {
                
                opp.Expected_Close_Date__c = dateMap.get(opp.Id);
            }
            
            Database.SaveResult[] results = Database.update(opportunities, false);
            
            List<String> errors = new List<String>();
            
            for (Integer i = 0; i < results.size(); i++) {
                
                if (!results[i].isSuccess()) {
                    
                    Opportunity failedOpp = opportunities[i];
                    OpportunityWrapper wrapper = wrapperMap.get(failedOpp.Id);
                    
                    String oppNumber = wrapper != null
                        ? wrapper.oppIdFormat
                        : String.valueOf(failedOpp.Id);
                    
                    for (Database.Error err : results[i].getErrors()) {
                        
                        errors.add(
                            'Opportunity: ' + oppNumber +
                            '\nError: ' + err.getMessage()
                        );
                    }
                }
            }
            
            if (!errors.isEmpty()) {
                response.success = false;
                response.message =
                    'The following Opportunity(s) could not be updated:\n\n' +
                    String.join(errors, '\n\n');
                return response;
            }
            
            if (!errors.isEmpty()) {
                response.success = false;
                response.message = 'Error :\n\n' +   String.join(errors, '\n');
                return response;
            }
            
            response.success = true;
            response.message =
                opportunities.size() +
                ' Opportunity(s) updated successfully.';
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ex.getStackTraceString());
            
            response.success = false;
            response.message = 'Unable to save the Expected Closure Date. Please contact your administrator if the problem persists.';
        }
        
        return response;
    }
    
    
    public class SaveResponse {
        
        @AuraEnabled
        public Boolean success;
        
        @AuraEnabled
        public String message;
    }
    
    
    
    
    public class OpportunityWrapper {
        
        @AuraEnabled
        public Id opportunityId { get; set; }
        
        @AuraEnabled
        public String oppIdFormat {get;set;}
        
        @AuraEnabled
        public String opportunityName { get; set; }
        
        @AuraEnabled
        public String accountName { get; set; }
        
        @AuraEnabled
        public String formattedTcv { get; set; }
        
        @AuraEnabled
        public String formattedAcv { get; set; }
        
        @AuraEnabled
        public String stageName { get; set; }
        
        @AuraEnabled
        public Date closeDate { get; set; }
        
        @AuraEnabled
        public Date expectedClosureDate { get; set; }
        
        @AuraEnabled
        public String ownerName { get; set; }
        
        
    }
}