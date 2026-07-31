public without sharing class ResourceLineItemController {
    
    @AuraEnabled(Cacheable = true)
    public static Opportunity getOppDetails(Id oppId) {
        Opportunity opp = RevenueProjectionPopup.getOpportunityInfo(oppId);
        system.debug('opp: ' +opp);
        return opp;
    }
    
    @AuraEnabled
    public static List<RLIWrapper> getMasterDetails(String opportunityId) {
        
        //System.debug('opportunityId: ' + opportunityId);
        
        List<RLIWrapper> wrapperList = new List<RLIWrapper>();
        List<Resource_Line_Item__c> modificationList = new List<Resource_Line_Item__c>();
        
        String[] types = new String[]{'Resource_Line_Item__c'};
            String queryFields = '';
        
        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);
        
        for(Schema.DescribeSobjectResult res : results){
            
            Map<String, Schema.SObjectField> fieldMap = res.fields.getMap();
            
            for(Schema.SObjectField sfield : fieldMap.values()){
                
                Schema.DescribeFieldResult dfield = sfield.getDescribe();
                
                if(String.isBlank(queryFields)){
                    queryFields = dfield.getName();
                }else{
                    queryFields += ', ' + dfield.getName();
                }
            }
        }
        
        Opportunity opp;
        
        if(String.isNotBlank(opportunityId) && opportunityId != null){
            
            opp = RevenueProjectionPopup.getOpportunityInfo(opportunityId);
            
            String soqlQuery =
                'SELECT ' + queryFields +
                ' , Related_Opportunity__r.CurrencyIsoCode, Skill_Category_Matrix__r.Name, Experience1__r.Name ' +
                ' FROM Resource_Line_Item__c ' +
                ' WHERE Related_Opportunity__c = :opportunityId ' +
                ' ORDER BY CreatedDate ASC';
            
            System.debug('SOQL: ' + soqlQuery);
            
            modificationList = Database.query(soqlQuery);
        }
        
        Integer seq = 1;
        
        if(!modificationList.isEmpty()){
            
            if(!modificationList.isEmpty()){
                
                for(Resource_Line_Item__c rec : modificationList){
                    
                    RLIWrapper rli = new RLIWrapper(rec, seq, true);
                    if(rec.Sales_Selling_Rate__c != null && rec.Sales_Selling_Rate__c > 0){
                        rec.Sales_Selling_Rate__c = rec.Sales_Selling_Rate__c.setscale(2);
                    }
                    rli.sellingRate = rec.Selling_Rate__c != null ? rec.Selling_Rate__c.setScale(2) : 0;
                    rli.nonMSASellingRate = rec.Sales_Selling_Rate__c != null ? rec.Sales_Selling_Rate__c.setScale(2) : 0;
                    rli.convertedUnits = rec.Duration_Months_Calculated_c__c != null ? rec.Duration_Months_Calculated_c__c.setScale(2) : 0;
                    //rli.sellingRate = rec.Selling_Rate__c.setscale(2);
                    //rli.nonMSASellingRate = rec.Sales_Selling_Rate__c.setscale(2);
                    rli.isRecalculation = false;
                    //rli.convertedUnits = rec.Duration_Months_Calculated_c__c.setscale(2);
                    wrapperList.add(rli);
                    seq++;
                }
                
            }
            
        }else{
            
            Resource_Line_Item__c newRec = new Resource_Line_Item__c();
            newRec.Related_Opportunity__c = opportunityId;
            
            if(opp != null){
                newRec.Business_Unit__c = opp.Business_Unit_BU__c;
                newRec.Sub_Business_Unit__c = opp.Sub_Business_Unit__c;
                newRec.Sub_Skills__c = opp.Sub_Skills__c;
                newRec.CurrencyIsoCode = opp.CurrencyIsoCode;
                //newRec.Selling_Rate__c = rec.Selling_Rate__c;
            }
            
            wrapperList.add(new RLIWrapper(newRec, 1, false));
        }
        
        System.debug('WrapperList: ' + wrapperList);
        
        return wrapperList;
    }
    public static Decimal convertCurrency(Decimal amount, String fromCurrency, String toCurrency){
        
        System.debug('### convertCurrency START ###');
        System.debug('Input Amount: ' + amount);
        System.debug('From Currency: ' + fromCurrency);
        System.debug('To Currency: ' + toCurrency);
        
        if(amount == null || fromCurrency == null || toCurrency == null){
            System.debug('Invalid input detected. Returning original amount.');
            return amount;
        }
        
        if(fromCurrency == toCurrency){
            System.debug('Both currencies are same. No conversion needed.');
            return amount;
        }
        
        Map<String, Decimal> rateMap = new Map<String, Decimal>();
        
        for(CurrencyType ct : [
            SELECT IsoCode, ConversionRate
            FROM CurrencyType
            WHERE IsActive = true
        ]){
            rateMap.put(ct.IsoCode, ct.ConversionRate);
        }
        
        System.debug('Active Currency Rates: ' + rateMap);
        
        Decimal fromRate = rateMap.get(fromCurrency);
        Decimal toRate = rateMap.get(toCurrency);
        
        System.debug('From Rate (' + fromCurrency + '): ' + fromRate);
        System.debug('To Rate (' + toCurrency + '): ' + toRate);
        
        if(fromRate == null || toRate == null){
            System.debug('Currency rate missing. Returning original amount.');
            return amount;
        }
        
        // Step 1: Convert to corporate currency with high precision
        Decimal corporateAmount = amount.divide(fromRate, 12);
        System.debug('Amount in Corporate Currency: ' + corporateAmount);
        
        // Step 2: Convert to target currency
        Decimal convertedAmount = corporateAmount * toRate;
        
        System.debug('Converted Amount Before Rounding: ' + convertedAmount);
        
        Decimal finalAmount = convertedAmount.setScale(2);
        
        System.debug('Converted Amount After Rounding: ' + finalAmount);
        System.debug('### convertCurrency END ###');
        
        return finalAmount;
    }
    
    @AuraEnabled
    public static List<RLIWrapper> saveDetails(List<RLIWrapper> rows, Id opportunityId){
        
        List<Resource_Line_Item__c> insertList = new List<Resource_Line_Item__c>();
        List<Resource_Line_Item__c> updateList = new List<Resource_Line_Item__c>();
        
        System.debug('### saveDetails START ###');
        //System.debug('Input OpportunityId: ' + opportunityId);
        //System.debug('Input Rows: ' + JSON.serialize(rows));
        
        try{
            
            if(rows == null || rows.isEmpty()){
                System.debug('No rows received. Returning.');
                return rows;
            }
            
            Opportunity opp = [
                SELECT Id, AccountId, CurrencyIsoCode
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            
            //System.debug('Opportunity Retrieved: ' + JSON.serialize(opp));
            
            for(RLIWrapper wrap : rows){
                
                Resource_Line_Item__c rp = wrap.rliRecord;
                // System.debug('rp: '+rp);
                //System.debug('Status: '+ rp.Id + rp.Status__c);
                Boolean isTemp = false;
                isTemp = String.valueOf(rp.Id).startsWith('temp');
                
                Resource_Line_Item__c r = new Resource_Line_Item__c();
                
                r.Business_Unit__c = rp.Business_Unit__c;
                r.Sub_Business_Unit__c = rp.Sub_Business_Unit__c;
                //r.Category__c = rp.Category__c;
                r.Billing_Start_Date__c = rp.Billing_Start_Date__c;
                r.Region__c = rp.Region__c;
                if(rp.Region__c != null && rp.Region__c.equalsIgnoreCase('India')){
                    r.Region_Group__c = 'India / APAC';
                }else if(rp.Region__c != null && rp.Region__c.equalsIgnoreCase('USA')){
                    r.Region_Group__c = 'USA / Europe'; 
                }
                // r.CurrencyIsoCode = rp.CurrencyIsoCode;
                // r.CurrencyIsoCode = 
                r.CurrencyIsoCode = opp.CurrencyIsoCode;
                Decimal sellingRate = rp.Selling_Rate__c != null ? rp.Selling_Rate__c : 0;
                Decimal sellingRateNonMSA = rp.Sales_Selling_Rate__c != null ? rp.Sales_Selling_Rate__c : 0;
                
                if(!wrap.isMSA){
                    
                    Boolean isModified = sellingRateNonMSA != sellingRate;
                    Boolean isLower = sellingRateNonMSA < sellingRate;
                    r.Is_Rate_Modified__c = isModified;
                }
                
                String sourceCurrency = rp.CurrencyIsoCode;
                String targetCurrency = opp.CurrencyIsoCode;
                //System.debug('sourceCurrency: '+ sourceCurrency);
                //System.debug('targetCurrency: '+ targetCurrency);
                
                r.Selling_Rate__c = convertCurrency(sellingRate, sourceCurrency, targetCurrency);
                if(sourceCurrency != null && targetCurrency != null &&
                   sourceCurrency.equalsIgnoreCase('USD') &&
                   targetCurrency.equalsIgnoreCase('USD')){
                       
                       r.Sales_Selling_Rate__c = sellingRateNonMSA;
                   } else {
                       r.Sales_Selling_Rate__c = convertCurrency(sellingRateNonMSA, sourceCurrency, targetCurrency);
                   }                
                r.Experience__c = rp.Experience__c;
                r.Duration_Months__c = rp.Duration_Months__c;
                r.Status__c = rp.Status__c;
                r.Sales_Unit__c = rp.Sales_Unit__c;
                //r.Selling_Rate__c = rp.Selling_Rate__c != null ? rp.Selling_Rate__c : 0;
                //r.Skill_Functional_Area__c = rp.Skill_Functional_Area__c;
                r.Tentative_Start_Date__c = rp.Tentative_Start_Date__c;
                r.Number_of_Resources__c = rp.Number_of_Resources__c;
                r.Engineer_Name__c = rp.Engineer_Name__c;
                r.Sub_Skills__c = rp.Sub_Skills__c;
                r.Skill_Category_Matrix__c = rp.Skill_Category_Matrix__c;
                r.Experience1__c = rp.Experience1__c;
                r.Account__c = opp.AccountId;
                r.MSA_Customer__c = wrap.isMSA;
                if(String.isNotBlank(rp.Remarks__c)){
                    if(r.Status__c != null && r.Status__c.equalsIgnoreCase('Resource Fulfilled'))
                        r.Remarks__c = rp.Remarks__c;
                    else
                        r.Remarks__c = '';
                }
                if(rp.Lost_Remarks__c != null || String.isNotBlank(rp.Lost_Remarks__c)){
                    if(r.Status__c != null && r.Status__c.equalsIgnoreCase('Lost'))
                        r.Lost_Remarks__c = rp.Lost_Remarks__c;
                    else
                        r.Lost_Remarks__c = '';
                }
                if(rp.Lost_Reason__c != null || String.isNotBlank(rp.Lost_Reason__c)){
                    if(r.Status__c != null && r.Status__c.equalsIgnoreCase('Lost'))
                        r.Lost_Reason__c = rp.Lost_Reason__c;
                    else
                        r.Lost_Reason__c = '';
                }
                
                r.Related_Opportunity__c = opp.Id;
                
                if(!isTemp){
                    r.Id = rp.Id;
                    wrap.isNewRecordCreated = false;
                    updateList.add(r);
                }
                else{
                    wrap.isNewRecordCreated = true;
                    insertList.add(r);
                }
            }
            
            System.debug('insertList: '+insertList);
            
            if(!insertList.isEmpty()){
                
                insert insertList;
                
                Integer insertIndex = 0;
                
                for(RLIWrapper wrap : rows){
                    
                    if(wrap.isNewRecordCreated){
                        
                        wrap.rliRecord.Id = insertList[insertIndex].Id;
                        wrap.recordExists = true;
                        
                        insertIndex++;
                    }
                }
            }
            
            System.debug('updateList: '+updateList);
            
            if(!updateList.isEmpty()){
                update updateList;
            }
            
            return rows;
            
        }
        catch(Exception ex){
            
            System.debug('### ERROR in saveDetails ###');
            System.debug('Error Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            throw new AuraHandledException('Error Occurs : ' + ex.getMessage());
        }
    }
    
    
    
    @AuraEnabled
    public static List<RLIWrapper> getSellingRateInformation(List<RLIWrapper> rows, Id opportunityId){
        
        System.debug('### getSellingRateInformation START ###');
        
        try{
            
            if(rows == null || rows.isEmpty()){
                return rows;
            }
            
            Opportunity opp = [
                SELECT Id, AccountId, CurrencyIsoCode
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            
            Set<String> buSet = new Set<String>();
            Set<String> subBuSet = new Set<String>();
            Set<String> subskillsSet = new Set<String>();
            Set<String> expSet = new Set<String>();
            Set<String> regionSet = new Set<String>();
            Set<String> salesUnitSet = new Set<String>();
            Set<Id> skillsetmatrix = new Set<Id>();
            
            for(RLIWrapper wrap : rows){
                
                //if(!wrap.recordExists){
                
                Resource_Line_Item__c r = wrap.rliRecord;
                System.debug('r: '+r);
                if(wrap != null  && !wrap.isRecalculation && r.Selling_Rate__c != null && r.Selling_Rate__c > 0){
                    
                    wrap.sellingRate = (r.Selling_Rate__c != null)
                        ? Integer.valueOf(r.Selling_Rate__c)
                        : 0;
                    
                    wrap.currencyIsoCode = opp.CurrencyIsoCode;
                    r.CurrencyIsoCode = opp.CurrencyIsoCode;
                    
                    continue;
                }
                
                
                
                if(r.Business_Unit__c != null) buSet.add(r.Business_Unit__c);
                if(r.Sub_Business_Unit__c != null) subBuSet.add(r.Sub_Business_Unit__c);
                if(r.Experience1__c != null) expSet.add(r.Experience1__c);
                if(r.Region__c != null) regionSet.add(r.Region__c);
                if(r.Sales_Unit__c != null) salesUnitSet.add(r.Sales_Unit__c);
                if(r.Sub_Skills__c != null) subskillsSet.add(r.Sub_Skills__c);
                if(r.Skill_Category_Matrix__c != null) skillsetmatrix.add(r.Skill_Category_Matrix__c);
                //}
            }
            
            List<Rate_card_Line_Item__c> rateLines = [
                SELECT Id,
                Rate_Amount__c,
                CurrencyIsoCode,
                Business_Unit__c,
                Sub_Business_Unit__c,
                Experience__c,
                Experience1__c,
                Region__c,
                Sales_Unit__c,
                Sub_Skills__c,
                Rate_Card__r.Account__c,
                Rate_Card__r.Type__c,
                Rate_Card__r.Is_Active__c,
                Skill_Category__c,
                Skill_Category__r.Id,
                Skill_Category__r.Business_Unit__c,
                Skill_Category__r.Sub_Business_Unit__c,
                Skill_Category__r.Region__c,
                Skill_Category__r.Sub_Skills__c,
                Experience1__r.Business_Unit__c,
                Experience1__r.Sub_Business_Unit__c,
                Experience1__r.Region__c,
                Experience1__r.Sub_Skills__c
                
                //Skill_Category__r.Experience__c
                
                
                FROM Rate_card_Line_Item__c
                
                WHERE Skill_Category__r.Business_Unit__c IN :buSet
                AND Experience1__r.Business_Unit__c IN :buSet
                
                AND Experience1__r.Sub_Business_Unit__c IN :subBuSet
                AND Skill_Category__r.Sub_Business_Unit__c IN :subBuSet
                
                
                AND Experience1__r.Region__c IN :regionSet
                AND Skill_Category__r.Region__c IN :regionSet
                
                AND (
                    Experience1__r.Sub_Skills__c IN :subskillsSet OR
                    Experience1__r.Sub_Skills__c = NULL
                )
                
                AND (
                    Skill_Category__r.Sub_Skills__c IN :subskillsSet OR
                    Skill_Category__r.Sub_Skills__c = NULL
                )
                
                AND Sales_Unit__c IN :salesUnitSet 
                AND CurrencyIsoCode =: opp.CurrencyIsoCode
                
                AND Experience1__c IN :expSet
                AND Skill_Category__c IN :skillsetmatrix
                
                AND Rate_Card__r.Is_Active__c = TRUE
            ];
            
            System.debug('Rate Lines Found: ' + rateLines.size());
            
            Map<String, List<Rate_card_Line_Item__c>> rateMap = new Map<String, List<Rate_card_Line_Item__c>>();
            if(!rateLines.isEmpty()){
                
                for(Rate_card_Line_Item__c rc : rateLines){
                    
                    String key =  
                        rc.Skill_Category__c + '-' +
                        rc.Experience1__c + '-' +
                        rc.Sales_Unit__c;                    
                    
                    if(!rateMap.containsKey(key)){
                        rateMap.put(key, new List<Rate_card_Line_Item__c>());
                    }
                    System.debug('Generated Key: ' + key);
                    System.debug('Available Keys: ' + rateMap.keySet());
                    
                    rateMap.get(key).add(rc);
                }
            }
            
            System.debug('Rate Map Keys: ' + rateMap.keySet());
            if(!rows.isEmpty()){
                for(RLIWrapper wrap : rows){
                    if(wrap == null || wrap.rliRecord == null){
                        continue;
                    }
                    Boolean isMSA = wrap.isMSA == true;
                    Boolean isNonMSA = wrap.isNonMSA == true;
                    
                    System.debug('FINAL isMSA: ' + isMSA);
                    System.debug('FINAL isNonMSA: ' + isNonMSA);
                    
                    
                    Resource_Line_Item__c r = wrap.rliRecord;
                    
                    if(!wrap.isRecalculation && r.Selling_Rate__c != null && r.Selling_Rate__c > 0){
                        wrap.sellingRate = r.Selling_Rate__c;
                        wrap.currencyIsoCode = opp.CurrencyIsoCode;
                        r.CurrencyIsoCode = opp.CurrencyIsoCode;
                        
                        if(r.Region__c != null && r.Region__c.equalsIgnoreCase('India')){
                            r.Region_Group__c = 'India / APAC';
                        }else if(r.Region__c != null && r.Region__c.equalsIgnoreCase('USA')){
                            r.Region_Group__c = 'USA / Europe'; 
                        }
                        Decimal convertedUnits = SalesUnitUtil.getConvertedUnits(
                            r.Duration_Months__c,
                            r.Region__c,
                            r.Sales_Unit__c
                        );
                        
                        System.debug('--- Conversion Debug Start ---');
                        System.debug('Duration (Months): ' + r.Duration_Months__c);
                        System.debug('Region Group: ' + r.Region_Group__c);
                        System.debug('Sales Unit: ' + r.Sales_Unit__c);
                        System.debug('Converted Units: ' + convertedUnits);
                        System.debug('--- Conversion Debug End ---');
                        wrap.convertedUnits = convertedUnits != null ? Integer.valueOf(convertedUnits) : 0;
                        continue;
                    }
                    
                    System.debug('r: '+r.Sales_Unit__c);
                    String key = 
                        r.Skill_Category_Matrix__c + '-' +
                        r.Experience1__c + '-' +
                        r.Sales_Unit__c;
                    
                    Boolean matchFound = false;
                    if(rateMap.containsKey(key)) {
                        
                        List<Rate_card_Line_Item__c> matchedRates = rateMap.get(key);
                        System.debug('matchedRates' + matchedRates);
                        if(!matchedRates.isEmpty()){
                            for(Rate_card_Line_Item__c rc : matchedRates){
                                
                                if(r.Region__c != null && r.Region__c.equalsIgnoreCase('India')){
                                    r.Region_Group__c = 'India / APAC';
                                }else if(r.Region__c != null && r.Region__c.equalsIgnoreCase('USA')){
                                    r.Region_Group__c = 'USA / Europe'; 
                                }
                                
                                Decimal convertedUnits = SalesUnitUtil.getConvertedUnits(
                                    r.Duration_Months__c,
                                    r.Region_Group__c,
                                    r.Sales_Unit__c
                                );
                                
                                wrap.convertedUnits = (convertedUnits != null)
                                    ? Integer.valueOf(convertedUnits)
                                    : 0;
                                
                                
                                System.debug('rc: '+rc.Sales_Unit__c);
                                System.debug('rc currency: '+rc.CurrencyIsoCode);
                                System.debug('opp currency: '+opp.CurrencyIsoCode);
                                
                                // ✅ If wrapper says MSA → prioritize MSA
                                if(isMSA && !isNonMSA && rc.Rate_Card__r.Type__c == 'MSA' &&
                                   rc.Rate_Card__r.Account__c == opp.AccountId && rc.CurrencyIsoCode == opp.CurrencyIsoCode){
                                       
                                       wrap.sellingRate = rc.Rate_Amount__c;
                                       r.Selling_Rate__c = rc.Rate_Amount__c;
                                       
                                       wrap.isMSA = true;
                                       wrap.isNonMSA = false;
                                       
                                       r.CurrencyIsoCode = rc.CurrencyIsoCode;
                                       wrap.currencyIsoCode = rc.CurrencyIsoCode;
                                       
                                       wrap.rateCardLines = matchedRates;
                                       matchFound = true;
                                       break;
                                   }
                                
                                // ✅ If Non-MSA
                                if(isNonMSA && !isMSA && rc.Rate_Card__r.Type__c == 'Non MSA' && rc.CurrencyIsoCode == opp.CurrencyIsoCode){
                                    
                                    //wrap.sellingRate = rc.Rate_Amount__c;
                                    wrap.nonMSASellingRate = rc.Rate_Amount__c;
                                    r.Selling_Rate__c = rc.Rate_Amount__c;
                                    r.Sales_Selling_Rate__c = rc.Rate_Amount__c;
                                    wrap.sellingRate = rc.Rate_Amount__c;
                                    
                                    wrap.isMSA = false;
                                    wrap.isNonMSA = true;
                                    
                                    r.CurrencyIsoCode = rc.CurrencyIsoCode;
                                    wrap.currencyIsoCode = rc.CurrencyIsoCode;
                                    
                                    wrap.rateCardLines = matchedRates;
                                    matchFound = true;
                                    break;
                                }
                            }
                        }
                        
                    }
                    
                    if(!matchFound){
                        wrap.sellingRate = 0;
                        r.Selling_Rate__c = 0;
                    }
                    System.debug('matchFound: '+matchFound);
                    
                    System.debug('r.Selling_Rate__c: '+r.Selling_Rate__c);
                    System.debug('wrap.sellingRate: '+wrap.sellingRate);
                }
            }
            
            
            System.debug('### getSellingRateInformation END ###' + rows);
            System.debug('### getSellingRateInformation END ###' + rows.size());
            
            return rows;
            
        }catch(Exception ex){
            
            System.debug('Error Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            
            throw new AuraHandledException('Error while fetching Selling Rate: ' + ex.getMessage());
        }
    }
    
    
    public class RLIWrapper {
        public RLIWrapper(){}
        
        @AuraEnabled
        public Resource_Line_Item__c rliRecord { get; set; }
        
        @AuraEnabled
        public Integer sequenceNo { get; set; }
        
        @AuraEnabled
        public Boolean recordExists { get; set; }
        
        @AuraEnabled
        public Decimal sellingRate {get;set;}
        
        @AuraEnabled
        public Decimal convertedUnits {get;set;}
        
        @AuraENabled
        public Decimal nonMSASellingRate {get;set;}
        
        @AuraEnabled
        public Boolean isRecalculation {get;set;}
        
        @AuraEnabled
        public Boolean isMSA {get;set;}
        
        @AuraEnabled
        public Boolean isNonMSA {get;set;}
        
        @AuraEnabled
        public List<Rate_card_Line_Item__c> rateCardLines {get;set;}
        
        @AuraEnabled
        public Boolean isNewRecordCreated {get;set;}
        
        @AuraEnabled
        public String currencyIsoCode {get;set;}
        
        
        
        public RLIWrapper(Resource_Line_Item__c rli, Integer seq, Boolean existsFlag){
            this.rliRecord = rli;
            this.sequenceNo = seq;
            this.recordExists = existsFlag;
            this.rateCardLines = new List<Rate_card_Line_Item__c>();
            
        }
    }
    
    /*@AuraEnabled
public static list<sObject> fetchLookupData(string searchKey , string sObjectApiName, String projectId, String bu, String subBu, String skill, String experience, String region ) {
System.debug('sObjectApiName '+sObjectApiName);
System.debug('projectId '+projectId);
List <sObject> returnList = new List < sObject > ();
Set<Id> projectIdSet = new Set<Id>();
projectIdSet.add(projectId);
if(String.isNotBlank(searchKey) && String.isNotBlank(sObjectApiName) && sObjectApiName.equalsIgnoreCase('Skill_Category_Matrix__c')){
string sWildCardText = '%' + searchKey + '%';
string sQuery = 'Select Id, Name From ' + sObjectApiName + ' Where Name Like : sWildCardText AND (Customer__c IN: projectIdSet OR Customer__c = Null) order by createdDate DESC';
for (sObject obj: database.query(sQuery)) { 
returnList.add(obj);
}
}

System.debug('returnList: '+returnList);
System.debug('returnList: '+returnList.size());
return returnList;
}*/
    
    @AuraEnabled
    public static List<Skill_Category_Matrix__c> fetchSkillCategoryMatrix(
        String searchKey,
        String projectId,
        String bu,
        String subBu,
        String subSkills,
        String experience,
        String region,
        String skillId,
        String msaType
    ) {
        
        System.debug('================ START fetchSkillCategoryMatrix ================');
        
        Long startTime = System.currentTimeMillis();
        
        // 🔹 Input Logs
        System.debug('INPUT PARAMS --> ' +
                     'searchKey=' + searchKey +
                     ', projectId=' + projectId +
                     ', bu=' + bu +
                     ', subBu=' + subBu +
                     ', subSkills=' + subSkills +
                     ', experience=' + experience +
                     ', region=' + region +
                     ', skillId=' + skillId +
                     ', msaType=' + msaType
                    );
        
        Set<Id> projectIdSet = new Set<Id>();
        if (String.isNotBlank(projectId)) {
            projectIdSet.add(projectId);
        }
        
        String query = 'SELECT Id, Name FROM Skill_Category_Matrix__c';
        List<String> conditions = new List<String>();
        
        // 🔹 Customer filter
        if (!projectIdSet.isEmpty() && msaType.equalsIgnoreCase('Non MSA')) {
            conditions.add('(Customer__c = NULL)');
        }
        if (!projectIdSet.isEmpty() && msaType.equalsIgnoreCase('MSA')) {
            conditions.add('(Customer__c IN :projectIdSet)');
        }
        
        // 🔹 Filters
        if (String.isNotBlank(bu)) {
            conditions.add('Business_Unit__c = :bu');
        }
        
        if (String.isNotBlank(subBu)) {
            conditions.add('Sub_Business_Unit__c = :subBu');
        }
        
        if (String.isNotBlank(subSkills)) {
            conditions.add('Sub_Skills__c = :subSkills');
        }
        
        if (String.isNotBlank(region)) {
            conditions.add('Region__c = :region');
        }
        
        // WHERE
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        // ORDER
        if (String.isNotBlank(searchKey)) {
            query += ' ORDER BY Name ASC LIMIT 999';
        } else {
            query += ' ORDER BY CreatedDate DESC LIMIT 999';
        }
        
        // 🔹 Query Debug
        System.debug('FINAL QUERY --> ' + query);
        
        // 🔹 Execute Query
        List<Skill_Category_Matrix__c> results = Database.query(query);
        
        // 🔥 Important Debugs
        System.debug('TOTAL RECORDS RETURNED --> ' + results.size());
        
        // Full data (JSON view - BEST for readability)
        System.debug('RESULT DATA (JSON) --> ' + JSON.serializePretty(results));
        
        // Optional: Loop debug (first few records only)
        Integer limitLog = Math.min(results.size(), 5);
        for (Integer i = 0; i < limitLog; i++) {
            System.debug('Record [' + i + '] --> Id=' + results[i].Id + ', Name=' + results[i].Name);
        }
        
        Long endTime = System.currentTimeMillis();
        System.debug('EXECUTION TIME (ms) --> ' + (endTime - startTime));
        
        System.debug('================ END fetchSkillCategoryMatrix ================');
        
        return results;
    }
    
    @AuraEnabled
    public static List<Experience__c> fetchExperienceOptions(
        String searchKey,
        String projectId,
        String bu,
        String subBu,
        String subSkills,
        String experience,
        String region,
        String skillId,
        String msaType
    ) {
        
        System.debug('================ START fetchExperienceOptions ================');
        
        Long startTime = System.currentTimeMillis();
        
        // 🔹 Input Logs
        System.debug('INPUT PARAMS --> ' +
                     'searchKey=' + searchKey +
                     ', projectId=' + projectId +
                     ', bu=' + bu +
                     ', subBu=' + subBu +
                     ', subSkills=' + subSkills +
                     ', experience=' + experience +
                     ', region=' + region +
                     ', skillId=' + skillId +
                     ', msaType=' + msaType
                    );
        
        Set<Id> projectIdSet = new Set<Id>();
        if (String.isNotBlank(projectId)) {
            projectIdSet.add(projectId);
        }
        
        String query = 'SELECT Id, Name FROM Experience__c';
        List<String> conditions = new List<String>();
        
        // 🔹 Customer filter
        if (!projectIdSet.isEmpty() && msaType.equalsIgnoreCase('Non MSA')) {
            conditions.add('(Customer__c = NULL)');
        }
        if (!projectIdSet.isEmpty() && msaType.equalsIgnoreCase('MSA')) {
            conditions.add('(Customer__c IN :projectIdSet)');
        }
        
        // 🔹 Filters
        if (String.isNotBlank(bu)) {
            conditions.add('Business_Unit__c = :bu');
        }
        
        if (String.isNotBlank(subBu)) {
            conditions.add('Sub_Business_Unit__c = :subBu');
        }
        
        if (String.isNotBlank(subSkills)) {
            conditions.add('Sub_Skills__c = :subSkills');
        }
        
        if (String.isNotBlank(region)) {
            conditions.add('Region__c = :region');
        }
        
        // 🔍 SEARCH
        if (String.isNotBlank(searchKey)) {
            String sWildCardText = '%' + searchKey + '%';
            conditions.add('Name LIKE :sWildCardText');
        }
        
        // WHERE
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        // ORDER
        if (String.isNotBlank(searchKey)) {
            query += ' ORDER BY Name ASC LIMIT 999';
        } else {
            query += ' ORDER BY CreatedDate DESC LIMIT 999';
        }
        
        // 🔹 Query Debug
        System.debug('FINAL QUERY --> ' + query);
        
        // 🔹 Execute Query
        List<Experience__c> results = Database.query(query);
        
        // 🔥 Important Debugs
        System.debug('TOTAL RECORDS RETURNED --> ' + results.size());
        
        // Full data (JSON view - BEST for readability)
        System.debug('RESULT DATA (JSON) --> ' + JSON.serializePretty(results));
        
        // Optional: Loop debug (first few records only)
        Integer limitLog = Math.min(results.size(), 5);
        for (Integer i = 0; i < limitLog; i++) {
            System.debug('Record [' + i + '] --> Id=' + results[i].Id + ', Name=' + results[i].Name);
        }
        
        Long endTime = System.currentTimeMillis();
        System.debug('EXECUTION TIME (ms) --> ' + (endTime - startTime));
        
        System.debug('================ END fetchExperienceOptions ================');
        
        return results;
    }
    
    /* @AuraEnabled
public static List<Experience__c> fetchExperience(
String searchKey
) {
System.debug('===== fetchExperience START =====');

String query = 'SELECT Id, Name FROM Experience__c';

if (String.isNotBlank(searchKey)) {
String sWildCardText = '%' + searchKey + '%';
query += ' WHERE Name LIKE :sWildCardText';
query += ' ORDER BY Name ASC LIMIT 50';
} else {
query += ' ORDER BY CreatedDate DESC LIMIT 50';
}

System.debug('Final Query: ' + query);

return Database.query(query);
}*/
    
    @AuraEnabled
    public static List<sObject> fetchLookupData(
        String searchKey,
        String sObjectApiName,
        String projectId,
        String bu,
        String subBu,
        String skill,
        String experience,
        String region,
        String skillId
    ) {
        System.debug('===== fetchLookupData START =====');
        
        List<sObject> returnList = new List<sObject>();
        Set<Id> projectIdSet = new Set<Id>();
        
        if (String.isNotBlank(projectId)) {
            projectIdSet.add(projectId);
        }
        
        if (
            String.isNotBlank(sObjectApiName) &&
            (
                sObjectApiName.equalsIgnoreCase('Skill_Category_Matrix__c') ||
                sObjectApiName.equalsIgnoreCase('Experience__c')
            )
        ) {
            
            String query = 'SELECT Id, Name FROM ' + sObjectApiName;
            
            List<String> conditions = new List<String>();
            
            // ✅ Customer filter
            if (!projectIdSet.isEmpty()) {
                conditions.add('(Customer__c IN :projectIdSet OR Customer__c = NULL)');
            }
            
            // ==================================
            // 🔹 SEARCH MODE
            // ==================================
            if (String.isNotBlank(searchKey)) {
                
                String sWildCardText = '%' + searchKey + '%';
                conditions.add('Name LIKE :sWildCardText');
                
                // Build WHERE
                if (!conditions.isEmpty()) {
                    query += ' WHERE ' + String.join(conditions, ' AND ');
                }
                
                query += ' ORDER BY Name ASC LIMIT 50';
            }
            
            // ==================================
            // 🔹 DEFAULT MODE
            // ==================================
            else {
                
                if (!sObjectApiName.equalsIgnoreCase('Experience__c')) {
                    
                    if (String.isNotBlank(bu)) {
                        conditions.add('Business_Unit__c = :bu');
                    }
                    
                    if (String.isNotBlank(subBu)) {
                        conditions.add('Sub_Business_Unit__c = :subBu');
                    }
                    
                    if (String.isNotBlank(skill)) {
                        conditions.add('Sub_Skills__c = :skill');
                    }
                    
                    if (String.isNotBlank(region)) {
                        conditions.add('Region__c = :region');
                    }
                }
                
                // Build WHERE
                if (!conditions.isEmpty()) {
                    query += ' WHERE ' + String.join(conditions, ' AND ');
                }
                
                query += ' ORDER BY CreatedDate DESC';
            }
            
            System.debug('Final Query: ' + query);
            System.debug('Final Query: ' + query);
            returnList = Database.query(query);
        } 
        else {
            System.debug('⚠️ Conditions not met');
        }
        
        System.debug('===== fetchLookupData END =====');
        return returnList;
    }
    
    @AuraEnabled
    public static sObject fetchDefaultRecord(string recordId , string sObjectApiName) {
        System.debug('fetchDefaultRecord: '+recordId);
        string sRecId = recordId;
        string sQuery = 'Select Id,Name From ' + sObjectApiName + ' Where Id = : sRecId LIMIT 1';
        for (sObject obj: database.query(sQuery)) {
            System.debug('obj: '+obj);
            return obj;
        }
        System.debug('sQuery: '+sQuery);
        return null;
    }
    
    
    
    
    
}