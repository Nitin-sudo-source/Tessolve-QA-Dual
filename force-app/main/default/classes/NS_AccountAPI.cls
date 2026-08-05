@RestResource(urlMapping='/netsuite/accounts')
global without sharing class NS_AccountAPI {
    @testVisible
    static Boolean TEST_FORCE_EXCEPTION = false;
    public static final Set<String> ALLOWED_STAGES = new Set<String>{
        'Qualified',
            'Proposal',
            'Committed',
            'Closed Won'
            };
                
                @HttpGet
                global static List<AccountWrapper> getAccounts() {
                    
                    List<AccountWrapper> response = new List<AccountWrapper>();
                    
                    RestRequest req = RestContext.request;
                    String fromDate = req.params.get('fromDate');
                    String toDate = req.params.get('toDate');
                    //String lastSync = req.params.get('lastSync');
                    String manual   = req.params.get('manual');
                    String recordId = req.params.get('recordId');
                    String payload = JSON.serialize(req.params);
                    
                    try{
                        
                        if(TEST_FORCE_EXCEPTION){
                            throw new NullPointerException();
                        }   
                        
                        Datetime lastSyncDT;
                        Datetime fromDT;
                        Datetime toDT;
                        
                        if(String.isNotBlank(fromDate)){
                            try{
                                fromDT = (Datetime) JSON.deserialize(
                                    '"' + fromDate + '"',
                                    Datetime.class
                                );
                            }catch(Exception e){
                                RestContext.response.statusCode = 400;
                                // LOG ERROR
                                NS_IntegrationUtil.logError(
                                    null,
                                    'Account',
                                    'Daily',
                                    'Invalid fromDate format',
                                    400,
                                    fromDate
                                );
                                RestContext.response.responseBody =
                                    Blob.valueOf('Invalid fromDate format. Use ISO-8601 format like 2026-02-24T00:00:00Z');
                                return null;
                            }
                        }else{
                            fromDT = System.now().addDays(-1);
                        }
                        if(String.isNotBlank(toDate)){
                            try{
                                toDT = (Datetime) JSON.deserialize(
                                    '"' + toDate + '"',
                                    Datetime.class
                                );
                            }catch(Exception e){
                                RestContext.response.statusCode = 400;
                                // LOG ERROR
                                NS_IntegrationUtil.logError(
                                    null,
                                    'Account',
                                    'Daily',
                                    'Invalid toDate format',
                                    400,
                                    toDate
                                );
                                RestContext.response.responseBody =
                                    Blob.valueOf('Invalid toDate format. Use ISO-8601 format like 2026-02-24T00:00:00Z');
                                return null;
                            }
                        }else{
                            toDT = System.now().addDays(-1);
                        }
                        
                        List<Account> accList = new List<Account>();
                        
                        // Specific record mode
                        if(String.isNotBlank(recordId)){
                            
                            accList = [
                                SELECT Id, Name, BillingStreet, BillingCity,
                                BillingState, BillingCountry,
                                CurrencyIsoCode,
                                Primary_Subsidiary__c, Account_Group_Lookup__c, 
                                Account_Group__c,Account_Status__c, Netsuite_ID__c
                                FROM Account
                                WHERE Id = :recordId AND Netsuite_ID__c = NULL
                            ];
                        }
                        
                        // Manual pull mode
                        else if(manual == 'true'){
                            
                            accList = [
                                SELECT Id, Name, BillingStreet, BillingCity,
                                BillingState, BillingCountry,
                                CurrencyIsoCode,
                                Primary_Subsidiary__c, Account_Group_Lookup__c,
                                Account_Group__c,Account_Status__c,Netsuite_ID__c
                                FROM Account
                                WHERE NS_Manual_Pull__c = true AND Netsuite_ID__c = NULL
                                LIMIT :NS_IntegrationUtil.DEFAULT_LIMIT
                            ];
                        }
                        
                        else{
                            
                            accList = [
                                SELECT Id, Name, BillingStreet, BillingCity,
                                BillingState, BillingCountry,
                                CurrencyIsoCode,
                                Primary_Subsidiary__c,
                                Account_Group__c,Account_Status__c,Netsuite_ID__c
                                FROM Account
                                WHERE LastModifiedDate >= :fromDT
                                AND LastModifiedDate <= :toDT
                                //WHERE LastModifiedDate > :lastSyncDT 
                                AND Netsuite_ID__c = NULL
                                LIMIT :NS_IntegrationUtil.DEFAULT_LIMIT
                            ];
                        }
                        
                        // Get latest Opportunity per Account
                        Map<Id, Opportunity> latestOppMap = new Map<Id, Opportunity>();
                        
                        if(!accList.isEmpty()){
                            Set<Id> accIds = new Set<Id>();
                            for(Account a : accList){
                                accIds.add(a.Id);
                            }
                            
                            for(Opportunity opp : [
                                SELECT Id, AccountId, CurrencyIsoCode, StageName,
                                (SELECT ContactId, Contact.Name, IsPrimary
                                 FROM OpportunityContactRoles
                                 ORDER BY IsPrimary DESC, CreatedDate ASC
                                 LIMIT 1),
                                LastModifiedDate
                                FROM Opportunity
                                WHERE AccountId IN :accIds
                                AND StageName NOT IN ('Prequalified','Closed Lost')
                                ORDER BY CreatedDate DESC
                            ]){
                                System.debug('Current Stage: ' + opp.StageName);
                                System.debug('Current Account: ' + opp.AccountId);
                                if(!latestOppMap.containsKey(opp.AccountId)){
                                    latestOppMap.put(opp.AccountId, opp);
                                }
                            }
                        }
                        System.debug('Accounts found: ' + accList.size());
                        System.debug('Opps found: ' + latestOppMap.size());
                        
                        
                        for(Account acc : accList){
                            if(acc != null)
                                System.debug('Processing Account: ' + acc.Id);
                            
                            if(acc.NetSuite_Id__c != null){
                                continue;
                            }
                            Opportunity latestOpp = latestOppMap.get(acc.Id);
                            // Skip if no valid opportunity found
                            if(latestOpp == null){
                                continue;
                            }
                            response.add(new AccountWrapper(acc, latestOpp));
                        }
                        
                        RestContext.response.statusCode = 200;
                        
                    }catch(Exception e){
                        RestContext.response.statusCode = 500;
                        
                        // LOG ANY UNEXPECTED ERROR
                        NS_IntegrationUtil.logError(
                            null,
                            'Account',
                            (manual == 'true' ? 'Manual' : 'Daily'),
                            e.getMessage(),
                            500,
                            payload
                        );
                        RestContext.response.responseBody =
                            Blob.valueOf(JSON.serialize(
                                new Map<String,Object>{
                                    'success' => false,
                                        'message' => e.getMessage()
                                        }
                            ));
                        return null;
                    }
                    
                    return response;
                }
    
    global class AccountWrapper{
        public Id sfId;
        public String companyName;
        public String address1;
        public String address2;
        public String city;
        public String state;
        public String country;
        public String primaryCurrency;
        public String primarySubsidiary;
        public String customerAccountGroup;
        public String addressee;
        public String accountStatus;
        public String netSuiteCustomerId;
        
        public AccountWrapper(Account acc, Opportunity opp){
            sfId = acc.Id;
            companyName = acc.Name;
            //address1 = acc.BillingStreet;
            //address2 = acc.BillingStreet;
            //Address Split (min 3 chars rule)
            Map<String,String> splitAddr = NS_IntegrationUtil.splitAddress(acc.BillingStreet);
            
            address1 = splitAddr.get('line1');
            address2 = splitAddr.get('line2');
            city = acc.BillingCity;
            state = acc.BillingState;
            country = acc.BillingCountry;
            //primaryCurrency = acc.CurrencyIsoCode;
            primarySubsidiary = acc.Primary_Subsidiary__c;
            customerAccountGroup = acc.Account_Group__c;
            //Confirm this with Sudharshan
            //accountGroup = acc.Account_Group_Lookup__c;
            accountStatus = acc.Account_Status__c;
            netSuiteCustomerId = acc.Netsuite_ID__c;
            // Primary Currency (From Opportunity Currency)
            if(opp != null){
                primaryCurrency = opp.CurrencyIsoCode;
                
                if(opp.OpportunityContactRoles != null && !opp.OpportunityContactRoles.isEmpty()){
                    addressee = opp.OpportunityContactRoles[0].Contact.Name != null ? opp.OpportunityContactRoles[0].Contact.Name : 'NA';
                }
            }
            
            // Fallback safety
            if(String.isBlank(addressee)){
                addressee = companyName;
            }
        }
    }
}