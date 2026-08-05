public with sharing class RevenueExportUtility {
    public RevenueExportUtility() {
        
    }
    
    public static List<String> getOpportunityFields() {
        
        Map<String, Boolean> fieldMap = new Map<String, Boolean>();
        
        // Mandatory Fields
        fieldMap.put('Id', true);
        fieldMap.put('CurrencyIsoCode', true);
        fieldMap.put('TCV_in_Opportunity_Currency__c', true);
        fieldMap.put('ACV_in_Opportunity_Currency__c', true);
        fieldMap.put('OwnerId', true);
        fieldMap.put('AccountId', true);
        fieldMap.put('Geo__c', true);
        fieldMap.put('StageName', true);
        fieldMap.put('RecordType.Name', true);
        fieldMap.put('Business_Type__c', true);
        fieldMap.put('Business_Unit_BU__c', true);
        fieldMap.put('Sub_Business_Unit__c', true);
        fieldMap.put('CloseDate', true);
        fieldMap.put('Expected_Close_Date__c', true);
        fieldMap.put('CreatedDate', true);
        fieldMap.put('LastModifiedDate', true);
        
        for (Opportunity_Export_Field__mdt md : [
            SELECT Field_API_Name__c
            FROM Opportunity_Export_Field__mdt
            WHERE Is_Active__c = true
            ORDER BY Display_Order__c
        ]) {
            
            String fieldName = md.Field_API_Name__c;
            
            if (String.isNotBlank(fieldName)) {
                fieldMap.put(fieldName.trim(), true);
            }
        }
        
        return new List<String>(fieldMap.keySet());
    }
    
}