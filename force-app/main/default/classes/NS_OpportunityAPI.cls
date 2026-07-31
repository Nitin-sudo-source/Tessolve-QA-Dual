@RestResource(urlMapping='/netsuite/opportunities')
global without sharing class NS_OpportunityAPI {
    @testVisible
    static Boolean TEST_FORCE_EXCEPTION = false;
    
    @HttpGet
    global static List<OpportunityWrapper> getOpportunities(){
        
        List<OpportunityWrapper> response = new List<OpportunityWrapper>();
        RestRequest req = RestContext.request;
        
        // String lastSync = req.params.get('lastSync');
        String fromDate = req.params.get('fromDate');
        String toDate = req.params.get('toDate');
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
            
            /*if(String.isNotBlank(lastSync)){
try{
lastSyncDT = (Datetime) JSON.deserialize(
'"' + lastSync + '"',
Datetime.class
);
}catch(Exception e){
RestContext.response.statusCode = 400;
NS_IntegrationUtil.logError(
null,
'Opportunity',
'Daily',
'Invalid lastSync format',
400,
lastSync
);
RestContext.response.responseBody =
Blob.valueOf('Invalid lastSync format. Use ISO-8601 format like 2026-02-24T00:00:00Z');
return null;
}
}else{
lastSyncDT = System.now().addDays(-1);
}*/
            if(String.isNotBlank(fromDate)){
                try{
                    fromDT = (Datetime) JSON.deserialize(
                        '"' + fromDate + '"',
                        Datetime.class
                    );
                }catch(Exception e){
                    RestContext.response.statusCode = 400;
                    NS_IntegrationUtil.logError(
                        null,
                        'Opportunity',
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
                    NS_IntegrationUtil.logError(
                        null,
                        'Opportunity',
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
            
            List<Opportunity> oppList;
            
            // Specific record
            if(String.isNotBlank(recordId)){
                
                oppList = [
                    SELECT Id, Name, StageName, Amount,
                    TCV_in_Opportunity_Currency__c,
                    Business_Type__c, Engagement_Model__c,
                    CreatedDate, CurrencyIsoCode,
                    Opportunity_Number__c,
                    Opportunity_Id__c,
                    Netsuite_ID__c,
                    PO_Number__c, Owner.Name,
                    Probability, Description,
                    CloseDate, Competitors__c,
                    Closed_Lost_Reason__c,
                    Lost_Description__c,
                    Customer_Contact__c,
                    Account.Name,
                    Account.Account_Group__c,
                    Total_Resource_Line_Item__c,
                    Resource_Skills_Set_Required__c,
                    Execution_Location__c,
                    Technical_Owner__c,
                    LeadSource,
                    LastModifiedDate,
                    Area_of_Interest__c,TCV_in_USD__c,
                    Estimated_Project_Start_Date__c,
                    Win_Reason_Category__c, Win_Reason_Sub_Category__c,
                    ACV_in_Opportunity_Currency__c, Business_Unit_BU__c,
                    Sub_Business_Unit__c,RecordTypeId,RecordType.Name,
                    CY_Q1__c, CY_Q2__c,
                    CY_Q3__c, CY_Q4__c,NS_Sales_Order_Mapping__c,
                    Sub_Skills__c,
                    (SELECT Fiscal_Year__c,
                     Fiscal_Quarter__c,
                     Quarter_Amount__c
                     FROM Revenue_Projections__r)
                    FROM Opportunity
                    WHERE Id = :recordId
                ];
            }
            
            // Manual Pull
            else if(manual == 'true'){
                
                oppList = [
                    SELECT Id, Name, StageName, Amount,
                    TCV_in_Opportunity_Currency__c,
                    Business_Type__c, Engagement_Model__c,
                    CreatedDate, CurrencyIsoCode,
                    Opportunity_Number__c,
                    Opportunity_Id__c,
                    Netsuite_ID__c,
                    PO_Number__c, Owner.Name,
                    Probability, Description,
                    CloseDate, Competitors__c,
                    Closed_Lost_Reason__c,
                    Lost_Description__c,
                    Customer_Contact__c,
                    Account.Name,
                    Account.Account_Group__c,
                    Total_Resource_Line_Item__c,
                    Resource_Skills_Set_Required__c,
                    Execution_Location__c,
                    Technical_Owner__c,
                    LeadSource,
                    LastModifiedDate,
                    Area_of_Interest__c,TCV_in_USD__c,
                    Estimated_Project_Start_Date__c,
                    Win_Reason_Category__c, Win_Reason_Sub_Category__c,
                    ACV_in_Opportunity_Currency__c, Business_Unit_BU__c,
                    Sub_Business_Unit__c,RecordTypeId,RecordType.Name,
                    CY_Q1__c, CY_Q2__c,
                    CY_Q3__c, CY_Q4__c,NS_Sales_Order_Mapping__c,
                    Sub_Skills__c,
                    (SELECT Fiscal_Year__c,
                     Fiscal_Quarter__c,
                     Quarter_Amount__c
                     FROM Revenue_Projections__r)
                    FROM Opportunity
                    WHERE NS_Manual_Pull__c = true
                    LIMIT :NS_IntegrationUtil.DEFAULT_LIMIT
                ];
            }
            
            // Daily incremental
            else{
                
                oppList = [
                    SELECT Id, Name, StageName, Amount,
                    TCV_in_Opportunity_Currency__c,
                    Business_Type__c, Engagement_Model__c,
                    CreatedDate, CurrencyIsoCode,
                    Opportunity_Number__c,
                    Opportunity_Id__c,
                    Netsuite_ID__c,
                    PO_Number__c, Owner.Name,
                    Probability, Description,
                    CloseDate, Competitors__c,
                    Closed_Lost_Reason__c,
                    Lost_Description__c,
                    Customer_Contact__c,
                    Account.Name,
                    Account.Account_Group__c,
                    Total_Resource_Line_Item__c,
                    Resource_Skills_Set_Required__c,
                    Execution_Location__c,
                    Technical_Owner__c,
                    LeadSource,
                    LastModifiedDate,
                    Area_of_Interest__c,TCV_in_USD__c,
                    Estimated_Project_Start_Date__c,
                    Win_Reason_Category__c, Win_Reason_Sub_Category__c,
                    ACV_in_Opportunity_Currency__c, Business_Unit_BU__c,
                    Sub_Business_Unit__c,RecordTypeId,RecordType.Name,
                    CY_Q1__c, CY_Q2__c,
                    CY_Q3__c, CY_Q4__c,NS_Sales_Order_Mapping__c,
                    Sub_Skills__c,
                    
                    (SELECT Fiscal_Year__c,
                     Fiscal_Quarter__c,
                     Quarter_Amount__c
                     FROM Revenue_Projections__r)
                    FROM Opportunity
                    WHERE LastModifiedDate >= :fromDT
                    AND LastModifiedDate <= :toDT
                    LIMIT :NS_IntegrationUtil.DEFAULT_LIMIT
                ];
            }
            
            for(Opportunity opp : oppList){
                
                response.add(new OpportunityWrapper(opp));
                
            }
            
            RestContext.response.statusCode = 200;
            
        }catch(Exception e){
            
            RestContext.response.statusCode = 500;
            NS_IntegrationUtil.logError(
                null,
                'Opportunity',
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
    
    
    
    
    global class OpportunityWrapper{
        public Id sfId;
        public String title;
        public String opportunityStatus ;
        public String documentNumber; 
        public Decimal tcv;
        public Decimal TCVinUSD;
        public String opportunityCurrency;
        public Date closeDate;
        public Decimal probability;
        public String customer;
        public String description;
        public String salesRep;
        public String opportunityType;
        public String division;
        public String opportunityBusinessEngagementModel;
        public DateTime createdDate;
        public Date expectedClose;
        public String competitors;
        public String reasonforCloseLost;
        public String descriptionofLoss; 
        Public String customerContact; 
        Public Double resourceCount; 
        Public String resourceSkillsSetRequired; 
        public String opportunityExecutionLocation; 
        public String technicalOwner; 
        public String purchaseOrderNumber; 
        public String opportunityLeadSource; 
        public DateTime lastModified; 
        public String accountGroup; 
        public String areaofInterest; 
        public Date expectedProjectResourceStartDate; 
        public Double CYQ1; 
        public Double CYQ2; 
        public Double CYQ3; 
        public Double CYQ4; 
        public Double NYQ1; 
        public Double NYQ2; 
        public Double NYQ3; 
        public Double NYQ4; 
        public Double ExtY;
        public String businessUnit;
        public String subBusinessUnit;
        public String opportunityRecordType;
        public String winReasonCategory;
        public String winReasonSubCategory;
        public Double ACV;
        public String NSSalesOrderMapping;
        public String subSkills;
        public String netSuiteId;
        
        
        public OpportunityWrapper(Opportunity opp){
            sfId = opp.Id;
            title = opp.Name;
            opportunityStatus = opp.StageName;
            documentNumber = opp.Opportunity_Id__c;
            netSuiteId = opp.Netsuite_ID__c;
            tcv = opp.TCV_in_Opportunity_Currency__c;
            TCVinUSD = opp.TCV_in_USD__c;
            opportunityCurrency = opp.CurrencyIsoCode;
            closeDate = opp.CloseDate;
            probability = opp.Probability;
            customer = opp.Account.Name;
            description = opp.Description;
            opportunityType = opp.Business_Type__c;
            opportunityBusinessEngagementModel = opp.Engagement_Model__c;
            createdDate = opp.CreatedDate;
            competitors = opp.Competitors__c;
            reasonforCloseLost = opp.Closed_Lost_Reason__c;
            descriptionofLoss = opp.Lost_Description__c;
            customerContact = opp.Customer_Contact__c;
            resourceCount = opp.Total_Resource_Line_Item__c;
            resourceSkillsSetRequired = opp.Resource_Skills_Set_Required__c;
            opportunityExecutionLocation = opp.Execution_Location__c;
            technicalOwner = opp.Technical_Owner__c;
            opportunityLeadSource = opp.LeadSource; 
            lastModified = opp.LastModifiedDate;
            areaofInterest = opp.Area_of_Interest__c;
            expectedProjectResourceStartDate = opp.Estimated_Project_Start_Date__c;
            CYQ1 = opp.CY_Q1__c;
            CYQ2 = opp.CY_Q2__c;
            CYQ3 = opp.CY_Q3__c;
            CYQ4 = opp.CY_Q4__c;
            salesRep = opp.Owner.Name;
            purchaseOrderNumber = opp.PO_Number__c;
            accountGroup = opp.Account.Account_Group__c;
            businessUnit = opp.Business_Unit_BU__c;
            subBusinessUnit = opp.Sub_Business_Unit__c;
            opportunityRecordType = opp.RecordType != null ? opp.RecordType.Name: null;
            winReasonCategory = opp.Win_Reason_Category__c;
            winReasonSubCategory = opp.Win_Reason_Sub_Category__c;
            ACV = opp.ACV_in_Opportunity_Currency__c;
            NSSalesOrderMapping = opp.NS_Sales_Order_Mapping__c;
            subSkills = opp.Sub_Skills__c;
            // Initialize
            CYQ1 = 0; CYQ2 = 0; CYQ3 = 0; CYQ4 = 0;
            NYQ1 = 0; NYQ2 = 0; NYQ3 = 0; NYQ4 = 0;
            ExtY = 0;
            
            if(opp.Revenue_Projections__r != null &&
               !opp.Revenue_Projections__r.isEmpty()){
                   
                   Integer currentYear;
                   
                   // Step 1: Find Minimum Fiscal Year (CY)
                   for(Revenue_Projection__c rp : opp.Revenue_Projections__r){
                       if(rp.Fiscal_Year__c != null){
                           if(currentYear == null || rp.Fiscal_Year__c < currentYear){
                               currentYear = Integer.valueOf(rp.Fiscal_Year__c);
                           }
                       }
                   }
                   
                   Integer nextYear = currentYear != null ? currentYear + 1 : null;
                   
                   // Step 2: Assign values
                   for(Revenue_Projection__c rp : opp.Revenue_Projections__r){
                       
                       if(rp.Fiscal_Year__c == null || rp.Fiscal_Quarter__c == null){
                           continue;
                       }
                       
                       Integer fy = Integer.valueOf(rp.Fiscal_Year__c);
                       String fq = rp.Fiscal_Quarter__c;
                       Decimal amt = rp.Quarter_Amount__c != null ? rp.Quarter_Amount__c : 0;
                       
                       // CURRENT YEAR
                       if(fy == currentYear){
                           
                           if(fq == 'Q1') CYQ1 = amt;
                           else if(fq == 'Q2') CYQ2 = amt;
                           else if(fq == 'Q3') CYQ3 = amt;
                           else if(fq == 'Q4') CYQ4 = amt;
                       }
                       
                       // NEXT YEAR
                       else if(nextYear != null && fy == nextYear){
                           
                           if(fq == 'Q1') NYQ1 = amt;
                           else if(fq == 'Q2') NYQ2 = amt;
                           else if(fq == 'Q3') NYQ3 = amt;
                           else if(fq == 'Q4') NYQ4 = amt;
                       }
                       
                       // EXTENDED
                       if(fq == 'Extended'){
                           ExtY = amt;
                       }
                   }
               }
        }
    }
}