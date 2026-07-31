public Without Sharing class RevenueProjectionPopup {
    
    private static final String RT_TM = 'T_M';
    private static final Set<String> RT_MILESTONE =
        new Set<String>{'SoC_Services','IP','Pro_Video','ASIC'};
            private static final String SOURCE_RESOURCE = 'Resource';
    private static final String SOURCE_MILESTONE = 'Milestone';
    private static final String SOURCE_MANUAL = 'Manual';
    private static final String STATUS_ACTIVE = 'Active';
    private static final String STATUS_LOCKED = 'Locked';
    
    @AuraEnabled(Cacheable = true)
    public static Opportunity getOppDetails(Id oppId) {
        Opportunity opp = getOpportunityInfo(oppId);
        system.debug('opp: ' +opp);
        return opp;
    }
    
    
    public static Opportunity getOpportunityInfo(Id oppId) {
        List<Opportunity> oppList = new List<Opportunity>();
        String[] types = new String[]{'Opportunity'};
            string queryFields = '';
        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);
        
        for(Schema.DescribeSobjectResult res : results) {
            string sObjectname = res.getName();
            Map <String, Schema.SObjectField> fieldMap = res.fields.getMap();
            
            for(Schema.SObjectField sfield : fieldMap.Values()) { 
                schema.describefieldresult dfield = sfield.getDescribe();
                String fieldLabel = dfield.getLabel();
                
                if(queryFields == null || queryFields == '') {
                    queryFields = dField.getName();
                } else {
                    queryFields = queryFields + ', ' + dField.getName();
                }
            }
        }
        String soqlQuery = 'Select ' + queryFields  + ' from Opportunity Where Id = \''+oppId+'\''; 
        system.debug(soqlQuery);
        oppList = Database.query(soqlQuery);
        if (oppList.size() > 0) {
            return oppList[0];
        } else {
            return null;
        }
    }
    
    public static List<Revenue_Projection__c> getRevenueProjectionInfo(Id tId) {
        List<Revenue_Projection__c> schemeList = new List<Revenue_Projection__c>();
        String[] types = new String[]{'Revenue_Projection__c'};
            string queryFields = '';
        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);
        
        for(Schema.DescribeSobjectResult res : results) {
            string sObjectname = res.getName();
            Map <String, Schema.SObjectField> fieldMap = res.fields.getMap();
            
            for(Schema.SObjectField sfield : fieldMap.Values()) { 
                schema.describefieldresult dfield = sfield.getDescribe();
                String fieldLabel = dfield.getLabel();
                
                if(queryFields == null || queryFields == '') {
                    queryFields = dField.getName();
                } else {
                    queryFields = queryFields + ', ' + dField.getName();
                }
            }
        }
        String soqlQuery = 'Select ' + queryFields  + ' from Revenue_Projection__c Where Opportunity__c = \''+tId+'\''; 
        system.debug(soqlQuery);
        schemeList = Database.query(soqlQuery);
        if (schemeList.size() > 0) {
            return schemeList;
        } else {
            return null;
        }
    }
    
    @AuraEnabled
    public static List<RevenueWrapper> getRevenueInfo(Id schemeId) {
        System.debug('schemeId: '+schemeId);
        List<RevenueWrapper> psmWrapper = new List<RevenueWrapper>();
        List<Revenue_Projection__c> schemeList = getRevenueProjectionInfo(schemeId);
        if(schemeList != null){
            for(Revenue_Projection__c psm: schemeList){
                System.debug('psm: '+psm);
                if(psm.Quarter_Amount__c == null){
                    psm.Quarter_Amount__c = 0;
                }
                psmWrapper.add(new RevenueWrapper(psm));
            }
        }
        System.debug('psmWrapper: '+psmWrapper);
        if(!psmWrapper.isEmpty() && psmWrapper != null){
            return psmWrapper;
        }else{
            return null;
        }
    }
    
    @AuraEnabled
    public static List<RevenueWrapper> getBookingWrapper(Id oppId) {
        
        List<RevenueWrapper> wrapperList = new List<RevenueWrapper>();
        
        Opportunity opp = [
            SELECT Id, AccountId, CloseDate, CurrencyIsoCode
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        
        Integer currentFY;
        
        currentFY = (Date.today().month() >= 4) 
            ? Date.today().year() 
            : Date.today().year() - 1;
        System.debug('currentFY: '+currentFY);
        Revenue_Projection__c rp = new Revenue_Projection__c();
        rp.Opportunity__c = opp.Id;
        rp.Account__c = opp.AccountId;
        rp.Extended_Year__c = 0;
        rp.Id = null;
        
        List<Revenue_Projection__c> rpList = new List<Revenue_Projection__c>();
        
        
        Map<String, Object[]> quarterMap = new Map<String, Object[]>{
            'Current_FY_Q1__c' => new Object[]{currentFY, 'Q1', rp.Current_FY_Q1__c},
                'Current_FY_Q2__c' => new Object[]{currentFY, 'Q2', rp.Current_FY_Q2__c},
                    'Current_FY_Q3__c' => new Object[]{currentFY, 'Q3', rp.Current_FY_Q3__c},
                        'Current_FY_Q4__c' => new Object[]{currentFY, 'Q4', rp.Current_FY_Q4__c},
                            
                            'Next_FY_Q1__c' => new Object[]{currentFY+1, 'Q1', rp.Next_FY_Q1__c},
                                'Next_FY_Q2__c' => new Object[]{currentFY+1, 'Q2', rp.Next_FY_Q2__c},
                                    'Next_FY_Q3__c' => new Object[]{currentFY+1, 'Q3', rp.Next_FY_Q3__c},
                                        'Next_FY_Q4__c' => new Object[]{currentFY+1, 'Q4', rp.Next_FY_Q4__c}
        };
            
            for(String key : quarterMap.keySet()){
                
                Object[] data = quarterMap.get(key);
                
                Integer fy = (Integer)data[0];
                String q = (String)data[1];
                Decimal amount = (Decimal)data[2];
                
                if(amount == null || amount < 0){
                    amount = 0;
                }
                
                Integer qNum = Integer.valueOf(q.replace('Q',''));
                
                Date startDate = getQuarterStart(fy, qNum);
                Date endDate = getQuarterEnd(fy, qNum);
                
                Boolean isNotCurrentFY = (endDate < Date.today());
                
                Revenue_Projection__c newRP = new Revenue_Projection__c(
                    Opportunity__c = opp.Id,
                    Account__c = opp.AccountId,
                    Fiscal_Year__c = fy,
                    Fiscal_Quarter__c = q,
                    Quarter_Start_Date__c = startDate,
                    Quarter_End_Date__c = endDate,
                    Quarter_Amount__c = amount,
                    Is_Extended__c = false,
                    Is_Not_Current_FY__c = isNotCurrentFY,
                    Projection_Status__c = STATUS_ACTIVE,
                    Projection_Source__c = SOURCE_MANUAL,
                    CurrencyIsoCode = opp.CurrencyIsoCode
                );
                
                rpList.add(newRP);
            }
        
        
        Decimal extAmount = rp.Extended_Year__c;
        
        if(extAmount == null || extAmount < 0){
            extAmount = 0;
        }
        
        Revenue_Projection__c ext = new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Account__c = opp.AccountId,
            Fiscal_Year__c = currentFY + 2,
            Fiscal_Quarter__c = 'Extended',
            Quarter_Amount__c = extAmount,
            Is_Extended__c = true,
            Is_Not_Current_FY__c = false,
            Projection_Status__c = STATUS_ACTIVE,
            Projection_Source__c = SOURCE_MANUAL,
            CurrencyIsoCode = opp.CurrencyIsoCode
        );
        
        rpList.add(ext);
        
        
        // Convert to RevenueWrapper
        for(Revenue_Projection__c psm : rpList){
            
            if(psm.Quarter_Amount__c == null){
                psm.Quarter_Amount__c = 0;
            }
            
            wrapperList.add(new RevenueWrapper(psm));
        }
        System.debug('wrapperList: '+wrapperList);
        return wrapperList;
    }
    
    public static Date getQuarterStart(Integer fy, Integer q){
        
        if(q == 1) return Date.newInstance(fy, 4, 1);
        if(q == 2) return Date.newInstance(fy, 7, 1);
        if(q == 3) return Date.newInstance(fy, 10, 1);
        if(q == 4) return Date.newInstance(fy + 1, 1, 1);
        
        return null;
    }
    
    public static Date getQuarterEnd(Integer fy, Integer q){
        
        if(q == 1) return Date.newInstance(fy, 6, 30);
        if(q == 2) return Date.newInstance(fy, 9, 30);
        if(q == 3) return Date.newInstance(fy, 12, 31);
        if(q == 4) return Date.newInstance(fy + 1, 3, 31);
        
        return null;
    }
    
    @AuraEnabled
    public static Opportunity Save(List<RevenueWrapper> RevenueWrapperList, Id oppId){
        Opportunity opp = [
            SELECT Id, AccountId, CloseDate
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        System.debug('RevenueWrapperList: ' + RevenueWrapperList);
        List<Revenue_Projection__c> updateList = new List<Revenue_Projection__c>();
        for(RevenueWrapper rw : RevenueWrapperList){
            if(rw.psm != null){
                updateList.add(rw.psm);
            }
        }
        if(!updateList.isEmpty()){
            Database.SaveResult[] results = Database.insert(updateList, false);
            
            for(Database.SaveResult sr : results){
                if(!sr.isSuccess()){
                    System.debug('ERROR: ' + sr.getErrors()[0].getMessage());
                }
            }
        }
        
        /*if(!updateList.isEmpty()){
            insert updateList;
        }  */      
        return opp;
    }
    
    @AuraEnabled
    public static void UpdateRevenue(List<RevenueWrapper> RevenueWrapperList){
        System.debug('RevenueWrapperList: ' + RevenueWrapperList);
        
        List<Revenue_Projection__c> updateList = new List<Revenue_Projection__c>();
        for(RevenueWrapper rw : RevenueWrapperList){
            if(rw.psm != null){
                updateList.add(rw.psm);
            }
        }
        
        /*if(!updateList.isEmpty()){
            update updateList;
        }*/
        if(!updateList.isEmpty()){
            Database.SaveResult[] results = Database.update(updateList, false);
            
            for(Database.SaveResult sr : results){
                if(!sr.isSuccess()){
                    System.debug('ERROR: ' + sr.getErrors()[0].getMessage());
                }
            }
        }
        
    }
    
    public class RevenueWrapper {
        @AuraEnabled
        public Revenue_Projection__c psm {get;set;}
        public RevenueWrapper(){}
        public RevenueWrapper(Revenue_Projection__c psm){
            this.psm = psm;
        }
    }
}