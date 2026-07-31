public with sharing class NS_IntegrationUtil {

    public static Integer DEFAULT_LIMIT = 2000;

    // Generic method to log integration
   /* public static void logIntegration(
        Id recordId,
        String objectType,
        String pushType,
        String status,
        String errorMessage
    ){
        Integration_Log__c log = new Integration_Log__c();
        log.Record_Id__c = recordId;
        log.Object_Type__c = objectType;
        log.Push_Type__c = pushType;
        log.Status__c = status;
        log.Error_Message__c = errorMessage;
        log.Attempt_Date__c = System.now();
        insert log;
    }*/
    
     public static void logError(
        Id recordId,
        String objectType,
        String pushType,
        String errorMessage,
        Integer httpStatusCode,
        String payload
    ){
        try{
            Integration_Log__c log = new Integration_Log__c();

            log.Record_Id__c = recordId;
            log.Object_Type__c = objectType;
            log.Push_Type__c = pushType;
            log.Status__c = 'Failed';
            log.Error_Message__c = errorMessage;
            log.Attempt_Date__c = System.now();

            // Optional fields (add only if they exist in object)
            if(Schema.sObjectType.Integration_Log__c.fields.getMap().containsKey('HTTP_Status_Code__c')){
                log.put('HTTP_Status_Code__c', httpStatusCode);
            }

            if(Schema.sObjectType.Integration_Log__c.fields.getMap().containsKey('Payload__c')){
                log.put('Payload__c', payload);
            }

            insert log;

        }catch(Exception e){
            System.debug('Enhanced logging failed: ' + e.getMessage());
        }
    }

    // Mark record success
  /*  public static void markSuccess(SObject record){
        record.put('NS_Integration_Status__c','Success');
        record.put('NS_Last_Push_Date__c', System.now());
        record.put('NS_Error_Message__c', null);
        update record;
    }

    // Mark failure
    public static void markFailure(SObject record, String errorMsg){
        record.put('NS_Integration_Status__c','Failed');
        record.put('NS_Error_Message__c', errorMsg);
        update record;
    }*/
    
   public static Map<String,String> splitAddress(String billingStreet){

        Map<String,String> addressMap = new Map<String,String>();
    
        if(String.isBlank(billingStreet)){
            addressMap.put('line1','NA');
            addressMap.put('line2','NA');
            return addressMap;
        }
    
        billingStreet = billingStreet.trim();
    
        Integer maxLength = 12;
    
        // If full string fits
        if(billingStreet.length() <= maxLength){
            addressMap.put('line1', billingStreet);
            addressMap.put('line2', 'NA');
            return addressMap;
        }
    
        // Find last space before maxLength
        Integer splitIndex = billingStreet.lastIndexOf(' ', maxLength);
    
        // If no space found, fallback to hard split
        if(splitIndex == -1){
            splitIndex = maxLength;
        }
    
        String line1 = billingStreet.substring(0, splitIndex).trim();
        String line2 = billingStreet.substring(splitIndex).trim();
    
        // Ensure line2 minimum 3 characters
        if(line2.length() < 3){
            line2 = 'NA';
        }
    
        addressMap.put('line1', line1);
        addressMap.put('line2', line2);
    
        return addressMap;
    }
}