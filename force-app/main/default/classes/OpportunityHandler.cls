public class OpportunityHandler {
    
   /* public static void beforeInsert(List<Opportunity> oppList){
        System.debug('Handler beforeInsert called');
        
        Map<String, Id> rtMap = new Map<String, Id>();
        List<RecordType> rtList = new  List<RecordType>();
        rtList = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Opportunity'];
        for(RecordType rt : rtList){
            rtMap.put(rt.DeveloperName, rt.Id);
        }
        
        Id noneRtId = rtMap.get('None');
        
        for(Opportunity opp : oppList){
            
            System.debug('RecordTypeId: ' + opp.RecordTypeId);
            System.debug('AccountId: ' + opp.AccountId);
            System.debug('ContactId: ' + opp.ContactId);
            Boolean isLeadConversion = (opp.AccountId != null && opp.ContactId != null);
            System.debug('isLeadConversion: '+isLeadConversion);
            if(isLeadConversion && opp.RecordTypeId == noneRtId){
                opp.addError('Please select proper Opportunity Record Type. "None" is not allowed');
            }
            
        }
    }  */ 
    
}