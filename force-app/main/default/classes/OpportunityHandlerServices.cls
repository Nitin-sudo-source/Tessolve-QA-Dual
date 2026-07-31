public class OpportunityHandlerServices {
    
    public static void handleOpportunityCurrencyChange(Map<Id, String> oppOldCurrencyMap){
        //List<Financial_Currency_Audit__c> auditList = new List<Financial_Currency_Audit__c>();
        Set<Id> oppIds = oppOldCurrencyMap.keySet();
        
        if(oppIds == null || oppIds.isEmpty()){
            System.debug('No Opportunities provided for currency conversion.');
            return;
        }
        
        try{
            System.debug('Starting Currency Conversion for Opportunities: ' + oppIds);
            
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
                [SELECT Id, CurrencyIsoCode, Amount, TCV_in_Opportunity_Currency__c,  ACV_in_Opportunity_Currency__c
                 FROM Opportunity
                 WHERE Id IN :oppIds]
            );
            
            System.debug('Opportunities fetched: ' + oppMap.size());
            
            if(oppMap.isEmpty()){
                System.debug('No Opportunities found.');
                return;
            }
            
            Map<String, Decimal> rateMap = getCurrencyRates();
            System.debug('Currency Rates loaded: ' + rateMap);
            // Update Opportunity Amount
            //updateOpportunityAmount(oppMap, rateMap, oppOldCurrencyMap);
            
            updateOpportunityAmount(oppMap, rateMap, oppOldCurrencyMap);
            updateRLI(oppIds, oppMap, rateMap);
            updateRevenueProjection(oppIds, oppMap, rateMap);
            updatePaymentSchedule(oppIds, oppMap, rateMap);
            
            System.debug('Currency Conversion Completed Successfully.');
        }
        catch(Exception ex){
            System.debug('Currency Conversion Error: ' + ex.getMessage());
            System.debug('Line: ' + ex.getLineNumber());
        }
    }
    
    public static Decimal convertAndAudit(
        
        Id oppId,
        String recordTypeName,
        Id recordId,
        String fromCurrency,
        String toCurrency,
        Decimal amount,
        Map<String, Decimal> rateMap
    ){
        if(amount == null) return amount;
        
        Decimal fromRate = rateMap.get(fromCurrency);
        Decimal toRate   = rateMap.get(toCurrency);
        
        if(fromRate == null || toRate == null || fromRate == 0){
            return amount;
        }
        
        // ✅ STANDARD FORMULA (ONLY ONE)
        Decimal converted = (amount / fromRate) * toRate;
        
        return converted;
    }
    
    
    private static void updateOpportunityAmount(
        Map<Id, Opportunity> oppMap,
        Map<String, Decimal> rateMap,
        Map<Id, String> oldCurrencyMap
    ){
        List<Opportunity> updateList = new List<Opportunity>();
        
        for(Id oppId : oppMap.keySet()){
            
            Opportunity opp = oppMap.get(oppId);
            String oldCurrency = oldCurrencyMap.get(oppId);
            String newCurrency = opp.CurrencyIsoCode;
            
            // ✅ Convert base values
            Decimal newAmount = convertAndAudit(
                oppId, 'Opportunity', oppId,
                oldCurrency, newCurrency, opp.Amount, rateMap
            );
            
            Decimal newTCV = convertAndAudit(
                oppId, 'Opportunity', oppId,
                oldCurrency, newCurrency, opp.TCV_in_Opportunity_Currency__c, rateMap
            );
            
            Decimal newACV = convertAndAudit(
                oppId, 'Opportunity', oppId,
                oldCurrency, newCurrency, opp.ACV_in_Opportunity_Currency__c, rateMap
            );
            
            // ✅ Convert to USD ONLY ONCE
            Decimal usdRate = rateMap.get('USD');
            Decimal srcRate = rateMap.get(newCurrency);
            
            Decimal tcvUSD = (newTCV != null && srcRate != null && usdRate != null)
                ? (newTCV / srcRate) * usdRate
                : null;
            
            Decimal acvUSD = (newACV != null && srcRate != null && usdRate != null)
                ? (newACV / srcRate) * usdRate
                : null;
            
            // ✅ ROUND ONLY HERE
            opp.Amount = newAmount != null ? newAmount.setScale(2) : null;
            opp.TCV_in_Opportunity_Currency__c = newTCV != null ? newTCV.setScale(2) : null;
            opp.ACV_in_Opportunity_Currency__c = newACV != null ? newACV.setScale(2) : null;
            
            opp.TCV_in_USD__c = tcvUSD != null ? tcvUSD.setScale(2) : null;
            opp.Annual_Contract_Value_ACV_In_USD__c = acvUSD != null ? acvUSD.setScale(2) : null;
            
            updateList.add(opp);
        }
        
        updateRecordsSafe(updateList, 'Opportunity');
    }
    
    
    
    /* ---------------- Currency Rates ---------------- */
    public static Map<String, Decimal> getCurrencyRates(){
        
        Map<String, Decimal> currencyRateMap = new Map<String, Decimal>();
        
        List<CurrencyType> currencyList = [
            SELECT IsoCode, ConversionRate
            FROM CurrencyType
            WHERE IsActive = true
        ];
        
        System.debug('Active Currency Types: ' + currencyList.size());
        
        for(CurrencyType ct : currencyList){
            currencyRateMap.put(ct.IsoCode, ct.ConversionRate);
        }
        
        return currencyRateMap;
    }
    
    
    /* ---------------- Conversion Logic ---------------- */
    public static Decimal convertAmount(Decimal amount, Decimal oldRate, Decimal newRate){
        if(amount == null || oldRate == null || newRate == null){
            return amount;
        }
        return amount * (newRate / oldRate);
    }
    
    
    /* ---------------- Resource Line Items ---------------- */
    private static void updateRLI(Set<Id> oppIds, Map<Id, Opportunity> oppMap, Map<String, Decimal> rateMap){
        List<Resource_Line_Item__c> rliList = new List<Resource_Line_Item__c>();
        List<Resource_Line_Item__c> updateList = new List<Resource_Line_Item__c>();
        
        rliList = [
            SELECT Id, Related_Opportunity__c, Selling_Rate__c, Sales_Selling_Rate__c,  CurrencyIsoCode, Projected_Revenue__c
            FROM Resource_Line_Item__c
            WHERE Related_Opportunity__c IN :oppIds
        ];
        
        System.debug('RLI Records Found: ' + rliList.size());
        
        for(Resource_Line_Item__c rli : rliList){
            
            Opportunity opp = oppMap.get(rli.Related_Opportunity__c);
            if(opp == null) continue;
            
            // ✅ STORE ORIGINAL CURRENCY FIRST
            String oldCurrency = rli.CurrencyIsoCode;
            String newCurrency = opp.CurrencyIsoCode;
            
            // ---------------- SELLING RATE ----------------
            Decimal newSellingRate = convertAndAudit(
                
                rli.Related_Opportunity__c,
                'Resource Line Item',
                rli.Id,
                oldCurrency,
                newCurrency,
                rli.Selling_Rate__c,
                rateMap
            );
            
            // ---------------- SALES SELLING RATE ----------------
            Decimal newSalesRate = convertAndAudit(
                
                rli.Related_Opportunity__c,
                'Resource Line Item',
                rli.Id,
                oldCurrency,
                newCurrency,
                rli.Sales_Selling_Rate__c,
                rateMap
            );
            
            // ✅ APPLY AFTER BOTH CALCULATIONS
            rli.Selling_Rate__c = newSellingRate;
            rli.Sales_Selling_Rate__c = newSalesRate;
            rli.CurrencyIsoCode = newCurrency;
            
            updateList.add(rli);
        }
        
        System.debug('RLI Records To Update: ' + updateList.size());
        
        updateRecordsSafe(updateList, 'Resource Line Item');
    }
    
    
    /* ---------------- Revenue Projection ---------------- */
    private static void updateRevenueProjection(Set<Id> oppIds, Map<Id, Opportunity> oppMap, Map<String, Decimal> rateMap){
        List<Revenue_Projection__c> revList = new List<Revenue_Projection__c>();
        List<Revenue_Projection__c> updateList = new List<Revenue_Projection__c>();
        
        revList = [
            SELECT Id, Opportunity__c, Quarter_Amount__c, CurrencyIsoCode
            FROM Revenue_Projection__c
            WHERE Opportunity__c IN :oppIds
        ];
        
        System.debug('Revenue Projection Records Found: ' + revList.size());
        
        for(Revenue_Projection__c rev : revList){
            
            Opportunity opp = oppMap.get(rev.Opportunity__c);
            if(opp == null) continue;
            
            Decimal oldRate = rateMap.get(rev.CurrencyIsoCode);
            Decimal newRate = rateMap.get(opp.CurrencyIsoCode);
            Decimal newAmount = convertAndAudit(
                
                rev.Opportunity__c,
                'Revenue Projection',
                rev.Id,
                rev.CurrencyIsoCode,
                opp.CurrencyIsoCode,
                rev.Quarter_Amount__c,
                rateMap
            );
            
            rev.Quarter_Amount__c = newAmount;
            rev.CurrencyIsoCode = opp.CurrencyIsoCode;
            
            updateList.add(rev);
        }
        
        System.debug('Revenue Projection Records To Update: ' + updateList.size());
        
        updateRecordsSafe(updateList, 'Revenue Projection');
    }
    
    
    /* ---------------- Payment Milestone ---------------- */
    private static void updatePaymentSchedule(Set<Id> oppIds, Map<Id, Opportunity> oppMap, Map<String, Decimal> rateMap){
        
        List<Payment_Milestone__c> payList = new List<Payment_Milestone__c>();
        List<Payment_Milestone__c> updateList = new List<Payment_Milestone__c>();
        
        payList = [
            SELECT Id, Opportunity__c, Amount__c, CurrencyIsoCode
            FROM Payment_Milestone__c
            WHERE Opportunity__c IN :oppIds
        ];
        
        System.debug('Payment Milestone Records Found: ' + payList.size());
        
        for(Payment_Milestone__c pay : payList){
            
            Opportunity opp = oppMap.get(pay.Opportunity__c);
            if(opp == null) continue;
            
            Decimal oldRate = rateMap.get(pay.CurrencyIsoCode);
            Decimal newRate = rateMap.get(opp.CurrencyIsoCode);
            Decimal newAmount = convertAndAudit(
                
                pay.Opportunity__c,
                'Payment Milestone',
                pay.Id,
                pay.CurrencyIsoCode,
                opp.CurrencyIsoCode,
                pay.Amount__c,
                rateMap
            );
            
            pay.Amount__c = newAmount;
            pay.CurrencyIsoCode = opp.CurrencyIsoCode;
            
            //pay.Amount__c = convertAmount(pay.Amount__c, oldRate, newRate);
            //pay.CurrencyIsoCode = opp.CurrencyIsoCode;
            
            updateList.add(pay);
        }
        
        System.debug('Payment Milestone Records To Update: ' + updateList.size());
        
        updateRecordsSafe(updateList, 'Payment Milestone');
    }
    
    
    /* ---------------- Safe Update ---------------- */
    private static void updateRecordsSafe(List<SObject> records, String objectName){
        
        if(records == null || records.isEmpty()){
            System.debug(objectName + ' - No records to update.');
            return;
        }
        
        Database.SaveResult[] results = Database.update(records, false);
        
        Integer successCount = 0;
        Integer failCount = 0;
        
        for(Database.SaveResult sr : results){
            System.debug('sr: '+sr);
            if(sr.isSuccess()){
                successCount++;
            }else{
                failCount++;
                for(Database.Error err : sr.getErrors()){
                    System.debug(objectName + ' Update Error: ' + err.getMessage());
                }
            }
        }
        
        System.debug(objectName + ' Update Success: ' + successCount);
        System.debug(objectName + ' Update Failed: ' + failCount);
    }
    
    public static void validateParentAmount(Set<Id> parentIds,List<Opportunity> oppList, Map<Id, Opportunity> oldMap) {
        if (parentIds == null || parentIds.isEmpty()) return;
        
        // Parent Map
        Map<Id, Opportunity> parentMap = new Map<Id, Opportunity>([
            SELECT Id, Amount, Name, Blanket_PO__c, Business_Type__c
            FROM Opportunity
            WHERE Id IN :parentIds AND Blanket_PO__c = TRUE
        ]);
        
        // Existing child opps (DB)
        List<Opportunity> childOpps = [
            SELECT Id, Parent_Opportunity__c, Amount, Blanket_PO__c, Business_Type__c
            FROM Opportunity
            WHERE Parent_Opportunity__c IN :parentIds 
        ];
        
        Map<Id, Decimal> parentToChildSum = new Map<Id, Decimal>();
        
        // 1️⃣ Sum DB children
        for (Opportunity child : childOpps) {
            Id pId = child.Parent_Opportunity__c;
            
            Decimal amt = (child.Amount == null ? 0 : child.Amount.setScale(2));
            
            parentToChildSum.put(
                pId,
                (parentToChildSum.get(pId) == null ? 0 : parentToChildSum.get(pId)) + amt
            );
        }
        
        // 2️⃣ Adjust for updates (REMOVE OLD VALUES)
        if (oldMap != null) {
            for (Opportunity oldOpp : oldMap.values()) {
                
                if (oldOpp.Parent_Opportunity__c == null) continue;
                
                Id pId = oldOpp.Parent_Opportunity__c;
                
                Decimal oldAmt = (oldOpp.Amount == null ? 0 : oldOpp.Amount.setScale(2));
                
                parentToChildSum.put(
                    pId,
                    (parentToChildSum.get(pId) == null ? 0 : parentToChildSum.get(pId)) - oldAmt
                );
            }
        }
        
        // 3️⃣ Add NEW values
        for (Opportunity opp : oppList) {
            
            if (opp.Parent_Opportunity__c == null) continue;
            
            Id pId = opp.Parent_Opportunity__c;
            
            Decimal newAmt = (opp.Amount == null ? 0 : opp.Amount.setScale(2));
            
            parentToChildSum.put(
                pId,
                (parentToChildSum.get(pId) == null ? 0 : parentToChildSum.get(pId)) + newAmt
            );
        }
        
        // 4️⃣ FINAL VALIDATION
        for (Opportunity opp : oppList) {
            
            if (opp.Parent_Opportunity__c == null) 
                continue;
            /*if (opp.Business_Type__c != null && opp.Business_Type__c.equalsIgnoreCase('Existing Account - Renewals')) {
                continue;
            }*/
            
            Opportunity parent = parentMap.get(opp.Parent_Opportunity__c);
            if (parent == null) continue;
            
            Decimal childSum = parentToChildSum.get(opp.Parent_Opportunity__c) == null
                ? 0
                : parentToChildSum.get(opp.Parent_Opportunity__c).setScale(2);
            
            Decimal parentAmt = (parent.Amount == null ? 0 : parent.Amount.setScale(2));
            
            if (childSum > parentAmt) {
                
                opp.addError(
                    '"' + parent.Name + '"\n\n' +
                    'Parent Amount: ' + parentAmt + '\n' +
                    'Total Child Amount: ' + childSum + '\n\n' +
                    'Total of all child opportunities cannot exceed the parent amount.'
                );
            }
        }
    }
    
}