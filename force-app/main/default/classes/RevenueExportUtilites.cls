public with sharing class RevenueExportUtilites {
    public RevenueExportUtilites() {
        
    }
    
    public static List<String> getOpportunityFields() {
        
        Map<String,String> fieldMap =
            new Map<String,String>();
        
        // Mandatory fields
        fieldMap.put('Id','Id');
        fieldMap.put('CurrencyIsoCode','CurrencyIsoCode');
        fieldMap.put(
            'TCV_in_Opportunity_Currency__c',
        'TCV_in_Opportunity_Currency__c'
            );
        
        fieldMap.put(
            'ACV_in_Opportunity_Currency__c',
        'ACV_in_Opportunity_Currency__c'
            );
        
        for(
            Opportunity_Export_Field__mdt md :
            [
            SELECT
                Field_API_Name__c
            FROM Opportunity_Export_Field__mdt
            WHERE Is_Active__c=true
            ORDER BY Display_Order__c
        ]
        ){
            
            if(String.isNotBlank(md.Field_API_Name__c)){
                
                fieldMap.put(
                    md.Field_API_Name__c.trim(),
                md.Field_API_Name__c.trim()
                    );
                
            }
            
        }
        
        return new List<String>(
            fieldMap.keySet()
            );
        
    }
}