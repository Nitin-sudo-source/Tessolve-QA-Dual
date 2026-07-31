public with sharing class RevenueProjectionPreviewController {

    @AuraEnabled(cacheable=false)
    public static List<RevenueProjectionExportQueueable.ExportWrapper> getPreview(
        Id opportunityId,
        Boolean exportAll
    ) {

        List<Opportunity> opportunities;
        if(exportAll == null){
            exportAll = true;
        }
        System.debug('exportAll: '+exportAll);

        if (exportAll) {
            opportunities = [
                SELECT Id,
                       Name,
                       Opportunity_Id__c,
                       Account.Name,
                       TCV_in_USD__c,
                       Annual_Contract_Value_ACV_In_USD__c
                FROM Opportunity
            ];
        } else {
            opportunities = [
                SELECT Id,
                       Name,
                       Opportunity_Id__c,
                       Account.Name,
                       TCV_in_USD__c,
                       Annual_Contract_Value_ACV_In_USD__c
                FROM Opportunity
                WHERE Id = :opportunityId
            ];
        }

        Map<Id, RevenueProjectionExportQueueable.ExportWrapper> exportMap =
            new Map<Id, RevenueProjectionExportQueueable.ExportWrapper>();

        // Create one wrapper for every Opportunity
        for (Opportunity opp : opportunities) {

            RevenueProjectionExportQueueable.ExportWrapper w =
                new RevenueProjectionExportQueueable.ExportWrapper();

            w.opportunityName = opp.Name;
            w.opportunityId = opp.Opportunity_Id__c;
            w.accountName = opp.Account != null ? opp.Account.Name : '';

            w.tcvUSD = opp.TCV_in_USD__c == null
                ? 0
                : opp.TCV_in_USD__c;

            w.acvUSD = opp.Annual_Contract_Value_ACV_In_USD__c == null
                ? 0
                : opp.Annual_Contract_Value_ACV_In_USD__c;

            w.revenueProjectionStatus = 'No Revenue Projection';

            exportMap.put(opp.Id, w);
        }

        List<Revenue_Projection__c> projections = [

            SELECT
                Opportunity__c,
                FY_Type__c,
                Fiscal_Quarter__c,
                Quarter_Amount__c,
                CurrencyIsoCode

            FROM Revenue_Projection__c

            WHERE Opportunity__c IN :exportMap.keySet()
        ];

        Map<String, Decimal> currencyRates = new Map<String, Decimal>();

        for (CurrencyType ct : [
            SELECT IsoCode, ConversionRate
            FROM CurrencyType
            WHERE IsActive = true
        ]) {
            currencyRates.put(ct.IsoCode, ct.ConversionRate);
        }

        Decimal usdRate = currencyRates.get('USD');

        for (Revenue_Projection__c rp : projections) {

            RevenueProjectionExportQueueable.ExportWrapper w =
                exportMap.get(rp.Opportunity__c);

            if (w == null) {
                continue;
            }

            w.revenueProjectionStatus = 'Has Revenue Projection';

            Decimal amount =
                rp.Quarter_Amount__c == null
                ? 0
                : rp.Quarter_Amount__c;

            if (rp.CurrencyIsoCode != 'USD') {

                Decimal sourceRate =
                    currencyRates.get(rp.CurrencyIsoCode);

                if (sourceRate != null) {

                    // Record Currency -> Corporate Currency
                    amount = amount / sourceRate;

                    // Corporate Currency -> USD
                    amount = amount * usdRate;
                }
            }

            if (rp.FY_Type__c == 'Current FY') {

                if (rp.Fiscal_Quarter__c == 'Q1')
                    w.q1 += amount;
                else if (rp.Fiscal_Quarter__c == 'Q2')
                    w.q2 += amount;
                else if (rp.Fiscal_Quarter__c == 'Q3')
                    w.q3 += amount;
                else if (rp.Fiscal_Quarter__c == 'Q4')
                    w.q4 += amount;

            } else if (rp.FY_Type__c == 'Next FY') {

                if (rp.Fiscal_Quarter__c == 'Q1')
                    w.q5 += amount;
                else if (rp.Fiscal_Quarter__c == 'Q2')
                    w.q6 += amount;
                else if (rp.Fiscal_Quarter__c == 'Q3')
                    w.q7 += amount;
                else if (rp.Fiscal_Quarter__c == 'Q4')
                    w.q8 += amount;

            } else if (rp.FY_Type__c == 'Extended') {

                w.extended += amount;
            }
        }

        return new List<RevenueProjectionExportQueueable.ExportWrapper>(
            exportMap.values()
        );
    }
}