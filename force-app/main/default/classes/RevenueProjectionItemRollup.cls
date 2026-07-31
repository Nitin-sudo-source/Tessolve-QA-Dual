public class RevenueProjectionItemRollup {
    
    public static void rollupData(Set<Id> oppIds){
        
        if(oppIds == null || oppIds.isEmpty()){
            return;
        }
        
        try {
            
            Map<Id, Decimal> oppToTCV = new Map<Id, Decimal>();
            Map<Id, Decimal> oppToACV = new Map<Id, Decimal>();
            Map<Id, String> oppCurrencyMap = new Map<Id, String>();
            
            // ✅ Get currency rates (same as main handler)
            Map<String, Decimal> rateMap = OpportunityHandlerServices.getCurrencyRates();
            
            // Fetch projections
            List<Revenue_Projection__c> rpList = [
                SELECT Opportunity__c,
                Quarter_Amount__c,
                FY_Type__c,
                Opportunity__r.CurrencyIsoCode
                FROM Revenue_Projection__c
                WHERE Opportunity__c IN :oppIds
                AND Quarter_Amount__c != null
            ];
            
            // ✅ Aggregate in base currency ONLY
            for(Revenue_Projection__c rp : rpList){
                
                Id oppId = rp.Opportunity__c;
                
                if(!oppCurrencyMap.containsKey(oppId)){
                    oppCurrencyMap.put(oppId, rp.Opportunity__r.CurrencyIsoCode);
                }
                
                Decimal amount = rp.Quarter_Amount__c;
                
                // TCV
                oppToTCV.put(
                    oppId,
                    (oppToTCV.get(oppId) == null ? 0 : oppToTCV.get(oppId)) + amount
                );
                
                // ACV
                if(rp.FY_Type__c == 'Current FY'){
                    oppToACV.put(
                        oppId,
                        (oppToACV.get(oppId) == null ? 0 : oppToACV.get(oppId)) + amount
                    );
                }
            }
            
            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            
            for(Id oppId : oppIds){
                
                Decimal tcv = oppToTCV.get(oppId) == null ? 0 : oppToTCV.get(oppId);
                Decimal acv = oppToACV.get(oppId) == null ? 0 : oppToACV.get(oppId);
                
                String currencyStr = oppCurrencyMap.get(oppId);
                
                Decimal tcvUSD;
                Decimal acvUSD;
                
                // ✅ Convert ONLY from total (same logic as OpportunityHandler)
                if(currencyStr != null && rateMap.containsKey(currencyStr)){
                    
                    Decimal srcRate = rateMap.get(currencyStr);
                    Decimal usdRate = rateMap.get('USD');
                    
                    if(srcRate != null && usdRate != null && srcRate != 0){
                        
                        tcvUSD = (tcv / srcRate) * usdRate;
                        acvUSD = (acv / srcRate) * usdRate;
                    }
                }
                
                // ✅ FINAL ROUNDING ONLY HERE
                oppsToUpdate.add(new Opportunity(
                    Id = oppId,
                    Amount = tcv != null ? tcv.setScale(2) : 0,
                    TCV_in_Opportunity_Currency__c = tcv != null ? tcv.setScale(2) : 0,
                    ACV_in_Opportunity_Currency__c = acv != null ? acv.setScale(2) : 0,
                    
                    TCV_in_USD__c = tcvUSD != null ? tcvUSD.setScale(2) : null,
                    Annual_Contract_Value_ACV_In_USD__c = acvUSD != null ? acvUSD.setScale(2) : null
                ));
            }
            
            if(!oppsToUpdate.isEmpty()){
                update oppsToUpdate;
            }
            
        } catch (Exception ex) {
            System.debug('Unexpected error in RevenueProjectionItemRollup: ' + ex.getMessage());
            throw ex;
        }
    }
}