public with sharing class RevenueProjectionExportQueueable implements Queueable {
    private Id opportunityId;
    private Boolean exportAll;
    private List<String> fieldApiNames;
    private String columnsJson;
    
    // New
    private Id lastOpportunityId;
    private Integer partNumber;
    
    private static final Integer QUERY_SIZE = 10000;
    
    public class ExportColumnWrapper {
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String label;
    }
    
    public RevenueProjectionExportQueueable(
        Id opportunityId,
    List<String> fieldApiNames,
    Boolean exportAll,
    String columnsJson,
    Id lastOpportunityId,
    Integer partNumber
    ) {
        this.opportunityId = opportunityId;
        this.exportAll = exportAll;
        this.fieldApiNames = fieldApiNames;
        this.columnsJson = columnsJson;
        
        this.lastOpportunityId = lastOpportunityId;
        this.partNumber = (partNumber == null) ? 1 : partNumber;
    }
    
    /*
     * One row per Opportunity
     */
    public class ExportWrapper {
        @AuraEnabled
        public String opportunitySFId;
        @AuraEnabled
        public String opportunityOwnerSFId;
        @AuraEnabled
        public String opportunityOwnerName;
        
        @AuraEnabled
        public String accountId;
        @AuraEnabled
        public String accountName;
        
        @AuraEnabled
        public String revenueProjectionIds;
        @AuraEnabled
        public Integer revenueProjectionIdsCount = 0;
        
        @AuraEnabled
        public String location;
        
        @AuraEnabled
        public String bussinessType;
        @AuraEnabled
        public String businessUnit;
        @AuraEnabled
        public String subbusinessUnit;
        
        @AuraEnabled
        public String stageName;
        @AuraEnabled
        public String recordTypeName;
        
        @AuraEnabled
        public Date closeDate;
        @AuraEnabled
        public Date expectedCloseDate;
        
        @AuraEnabled
        public Datetime createdDate;
        @AuraEnabled
        public Datetime lastModifiedDate;
        
        @AuraEnabled
        public String opportunityName;
        @AuraEnabled
        public String opportunityId;
        
        @AuraEnabled
        public String revenueProjectionStatus = 'No Revenue Projection';
        
        @AuraEnabled
        public Decimal tcvUSD = 0;
        @AuraEnabled
        public Decimal acvUSD = 0;
        
        @AuraEnabled
        public Decimal q1 = 0;
        @AuraEnabled
        public Decimal q2 = 0;
        @AuraEnabled
        public Decimal q3 = 0;
        @AuraEnabled
        public Decimal q4 = 0;
        
        @AuraEnabled
        public Decimal q5 = 0;
        @AuraEnabled
        public Decimal q6 = 0;
        @AuraEnabled
        public Decimal q7 = 0;
        @AuraEnabled
        public Decimal q8 = 0;
        
        @AuraEnabled
        public Decimal extended = 0;
    }
    
    private class ExportBatch {
        
        List<Opportunity> opportunities;
        
        List<ExportWrapper> wrappers;
        
        ExportBatch() {
            opportunities = new List<Opportunity>();
            wrappers = new List<ExportWrapper>();
        }
    }
    
    
    
    public void execute(QueueableContext context) {
        
        // List<ExportWrapper> wrappers = getPreviewData();
        ExportBatch batch = getPreviewData();
        
        List<ExportWrapper> wrappers = batch.wrappers;
        
        if (wrappers.isEmpty()) {
            return;
        }
        
        List<ExportColumnWrapper> exportColumns = parseExportColumns(columnsJson);
        
        if (exportColumns.isEmpty()) {
            throw new AuraHandledException('No export columns received.');
        }
        
        List<String> csvRows = new List<String>();
        
        // Header
        csvRows.add(buildCsvHeader(exportColumns));
        
        for (Integer i = 0; i < wrappers.size(); i++) {
            
            csvRows.add(
                buildCsvRow(
                batch.opportunities[i],
            wrappers[i],
            exportColumns
                )
                );
            
        }
        
        String fileName =
            'RevenueProjectionExport_Part_' +
            partNumber +
            '_' +
            Datetime.now().format('yyyyMMdd_HHmmss');
        
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName + '.csv';
        cv.VersionData = Blob.valueOf(String.join(csvRows, '\n'));
        
        insert cv;
        
        // Queue next batch if required
        enqueueNextQueueable(batch.opportunities);
        //enqueueNextQueueable();
    }
    
    private void enqueueNextQueueable(List<Opportunity> opportunities) {
        
        if (!exportAll) {
            return;
        }
        
        if (opportunities.isEmpty()) {
            return;
        }
        
        // Less than QUERY_SIZE means last batch
        if (opportunities.size() < QUERY_SIZE) {
            return;
        }
        
        Id lastId = opportunities[opportunities.size() - 1].Id;
        
        System.enqueueJob(
            
        new RevenueProjectionExportQueueable(
            
        opportunityId,
        
        fieldApiNames,
        
        exportAll,
        
        columnsJson,
        
        lastId,
        
        partNumber + 1
            
        )
            
        );
        
    }
    
    /**
     * Parse columns received from LWC
     */
    private static List<ExportColumnWrapper> parseExportColumns(
        String columnsJson
    ) {
        if (String.isBlank(columnsJson)) {
            return new List<ExportColumnWrapper>();
        }
        
        return (List<ExportColumnWrapper>) JSON.deserialize(
            columnsJson,
        List<ExportColumnWrapper>.class
            );
    }
    
    /**
     * Build CSV Header
     */
    private static String buildCsvHeader(List<ExportColumnWrapper> columns) {
        List<String> headers = new List<String>();
        
        for (ExportColumnWrapper col : columns) {
            headers.add(formatCsvValue(col.label));
        }
        
        return String.join(headers, ',');
    }
    
    /**
     * Build one CSV row
     */
    private static String buildCsvRow(
        Opportunity opp,
    ExportWrapper wrapper,
    List<ExportColumnWrapper> columns
    ) {
        
        Map<String, Object> valueMap =
            buildOpportunityValueMap(opp);
        
        valueMap.putAll(
            buildRevenueProjectionValueMap(wrapper)
            );
        
        List<String> row = new List<String>();
        
        for (ExportColumnWrapper col : columns) {
            
            Object value = valueMap.get(col.fieldName);
            
            row.add(formatCsvValue(value));
            
        }
        
        return String.join(row, ',');
        
    }
    
    /**
     * Converts ExportWrapper into Map<FieldName, Value>
     */
    private static Map<String, Object> buildRevenueProjectionValueMap(
        ExportWrapper wrapper
    ) {
        
        return new Map<String, Object>{
            
            'revenueProjectionStatus'   => wrapper.revenueProjectionStatus,
            'revenueProjectionIds'      => wrapper.revenueProjectionIds,
            'revenueProjectionIdsCount' => wrapper.revenueProjectionIdsCount,
            
            'tcvUSDFormatted' => roundDecimal(wrapper.tcvUSD),
            'acvUSDFormatted' => roundDecimal(wrapper.acvUSD),
            
            'q1Formatted' => roundDecimal(wrapper.q1),
            'q2Formatted' => roundDecimal(wrapper.q2),
            'q3Formatted' => roundDecimal(wrapper.q3),
            'q4Formatted' => roundDecimal(wrapper.q4),
            
            'q5Formatted' => roundDecimal(wrapper.q5),
            'q6Formatted' => roundDecimal(wrapper.q6),
            'q7Formatted' => roundDecimal(wrapper.q7),
            'q8Formatted' => roundDecimal(wrapper.q8),
            
            'extendedFormatted' => roundDecimal(wrapper.extended)
                
        };
        
    }
    private static Decimal roundDecimal(Decimal value) {
        
        return value == null
            ? 0
            : value.setScale(2, RoundingMode.HALF_UP);
        
    }
    /**
     * Formats any Apex value into a CSV-safe string
     */
    private static String formatCsvValue(Object value) {
        if (value == null) {
            return '""';
        }
        
        String text;
        
        if (value instanceof Datetime) {
            
            text = ((Datetime)value).format('yyyy-MM-dd HH:mm:ss');
            
        } else if (value instanceof Date) {
            
            text = String.valueOf((Date)value);
            
        } else if (value instanceof Decimal) {
            
            Decimal d = (Decimal)value;
            text = String.valueOf(
                d.setScale(2, RoundingMode.HALF_UP)
                );
            
        } else if (value instanceof Integer) {
            
            text = String.valueOf((Integer)value);
            
        } else if (value instanceof Long) {
            
            text = String.valueOf((Long)value);
            
        } else if (value instanceof Boolean) {
            
            text = String.valueOf((Boolean)value);
            
        } else {
            
            text = String.valueOf(value);
            
        }
        
        text = text.replace('"', '""');
        
        return '"' + text + '"';
    }
    
    private ExportBatch getPreviewData(
        /*Id opportunityId,
    Boolean exportAll,
    List<String> fieldApiNames,
    String columnsJson*/
    ) {
        /*  List<Opportunity> opportunities = getOpportunities(
        opportunityId,
        exportAll
            );*/
            List<Opportunity> opportunities = getOpportunities();
        
        Map<String, Decimal> currencyRates = new Map<String, Decimal>();
        
        for (CurrencyType ct : [
            SELECT IsoCode, ConversionRate
            FROM CurrencyType
            WHERE IsActive = TRUE
        ]) {
            currencyRates.put(ct.IsoCode, ct.ConversionRate);
        }
        
        Map<Id, ExportWrapper> exportMap = new Map<Id, ExportWrapper>();
        
        for (Opportunity opp : opportunities) {
            ExportWrapper wrapper = buildExportWrapper(opp, currencyRates);
            
            exportMap.put(opp.Id, wrapper);
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
        
        for (Revenue_Projection__c rp : projections) {
            ExportWrapper wrapper = exportMap.get(rp.Opportunity__c);
            
            if (wrapper == null) {
                continue;
            }
            
            if (String.isBlank(wrapper.revenueProjectionIds)) {
                wrapper.revenueProjectionIds = rp.Id;
            } else {
                wrapper.revenueProjectionIds += ';' + rp.Id;
            }
            
            wrapper.revenueProjectionIdsCount = wrapper.revenueProjectionIds.split(
                ';'
                )
                .size();
            
            wrapper.revenueProjectionStatus = 'Has Revenue Projection';
            
            Decimal amount = convertToUSD(
                rp.Quarter_Amount__c,
            rp.CurrencyIsoCode,
            currencyRates
                );
            
            assignQuarterAmount(wrapper, rp, amount);
        }
        
        ExportBatch batch = new ExportBatch();
        
        batch.opportunities = opportunities;
        
        batch.wrappers = new List<ExportWrapper>();
        
        for (Opportunity opp : opportunities) {
            batch.wrappers.add(exportMap.get(opp.Id));
        }
        
        return batch;
        
        //return new List<ExportWrapper>(exportMap.values());
    }
    private List<Opportunity> getOpportunities() {
        
        List<String> fields = RevenueExportUtility.getOpportunityFields();
        
        Map<String, Schema.SObjectField> opportunityFields =
            Schema.SObjectType.Opportunity.fields.getMap();
        
        List<String> validFields = new List<String>();
        
        for (String fieldName : fields) {
            
            // Allow relationship fields
            if (fieldName.contains('.')) {
                validFields.add(fieldName);
                continue;
            }
            
            // Validate Opportunity fields
            if (opportunityFields.containsKey(fieldName)) {
                validFields.add(fieldName);
            } else {
                System.debug(
                    LoggingLevel.WARN,
                'Ignoring invalid Opportunity field: ' + fieldName
                    );
            }
        }
        
        String query =
            'SELECT ' +
            String.join(validFields, ',') +
            ' FROM Opportunity';
        
        if (!exportAll) {
            
            query += ' WHERE Id = :opportunityId';
            
        } else {
            
            if (lastOpportunityId != null) {
                query += ' WHERE Id > :lastOpportunityId';
            }
            
            query += ' ORDER BY Id';
            query += ' LIMIT ' + QUERY_SIZE;
        }
        
        return Database.query(query);
    }
    
    
    // private List<Opportunity> getOpportunities() {
        
        //     if (!exportAll) {
            //         return [
            //             SELECT
            //             Id,
            //             Name,
            //             ACV_in_Opportunity_Currency__c,
            //             TCV_in_Opportunity_Currency__c,
            //             CurrencyIsoCode,
            //             Opportunity_Id__c,
            //             Owner.Name,
            //             OwnerId,
            //             AccountId,
            //             Account.Name,
            //             StageName,
            //             CloseDate,
            //             CreatedDate,
            //             LastModifiedDate,
            //             TCV_in_USD__c,
            //             Annual_Contract_Value_ACV_In_USD__c,
            //             Expected_Close_Date__c,
            //             Business_Unit_BU__c,
            //             Sub_Business_Unit__c,
            //             Execution_Location__c,
            //             Geo__c,
            //             Business_Type__c,
            //             RecordType.Name
            //             FROM Opportunity
            //             WHERE Id = :opportunityId
            //         ];
        //     }
        
        //     if (lastOpportunityId == null) {
            
            //         return [
            //             SELECT
            //             Id,
            //             Name,
            //             ACV_in_Opportunity_Currency__c,
            //             TCV_in_Opportunity_Currency__c,
            //             CurrencyIsoCode,
            //             Opportunity_Id__c,
            //             Owner.Name,
            //             OwnerId,
            //             AccountId,
            //             Account.Name,
            //             StageName,
            //             CloseDate,
            //             CreatedDate,
            //             LastModifiedDate,
            //             TCV_in_USD__c,
            //             Annual_Contract_Value_ACV_In_USD__c,
            //             Expected_Close_Date__c,
            //             Business_Unit_BU__c,
            //             Sub_Business_Unit__c,
            //             Execution_Location__c,
            //             Geo__c,
            //             Business_Type__c,
            //             RecordType.Name
            //             FROM Opportunity
            //             ORDER BY Id
            //             LIMIT :QUERY_SIZE
            //         ];
        //     }
        
        //     return [
        //         SELECT
        //         Id,
        //         Name,
        //         ACV_in_Opportunity_Currency__c,
        //         TCV_in_Opportunity_Currency__c,
        //         CurrencyIsoCode,
        //         Opportunity_Id__c,
        //         Owner.Name,
        //         OwnerId,
        //         AccountId,
        //         Account.Name,
        //         StageName,
        //         CloseDate,
        //         CreatedDate,
        //         LastModifiedDate,
        //         TCV_in_USD__c,
        //         Annual_Contract_Value_ACV_In_USD__c,
        //         Expected_Close_Date__c,
        //         Business_Unit_BU__c,
        //         Sub_Business_Unit__c,
        //         Execution_Location__c,
        //         Geo__c,
        //         Business_Type__c,
        //         RecordType.Name
        //         FROM Opportunity
        //         WHERE Id > :lastOpportunityId
        //         ORDER BY Id
        //         LIMIT :QUERY_SIZE
        //     ];
    // }
    
    
    private static Map<String, Object> buildOpportunityValueMap(
        Opportunity opp
    ) {
        
        Map<String, Object> valueMap = new Map<String, Object>();
        
        valueMap.putAll(opp.getPopulatedFieldsAsMap());
        
        if (opp.Owner != null) {
            valueMap.put('Owner.Name', opp.Owner.Name);
        }
        
        if (opp.Account != null) {
            valueMap.put('Account.Name', opp.Account.Name);
        }
        
        if (opp.RecordType != null) {
            valueMap.put('RecordType.Name', opp.RecordType.Name);
        }
        
        return valueMap;
    }
    /**
     * Creates ExportWrapper from Opportunity
     */
    private static ExportWrapper buildExportWrapper(
        Opportunity opp,
    Map<String, Decimal> currencyRates
    ) {
        ExportWrapper w = new ExportWrapper();
        
        // w.opportunityName = opp.Name;
        // w.opportunitySFId = opp.Id;
        // w.opportunityId = opp.Opportunity_Id__c;
        
        // w.accountId = opp.AccountId;
        // w.accountName = opp.Account != null ? opp.Account.Name : '';
        
        // w.opportunityOwnerSFId = opp.OwnerId;
        // w.opportunityOwnerName = opp.Owner != null ? opp.Owner.Name : '';
        
        // w.location = opp.Geo__c;
        
        // w.stageName = opp.StageName;
        // w.recordTypeName = opp.RecordType != null ? opp.RecordType.Name : '';
        
        // w.bussinessType = opp.Business_Type__c;
        // w.businessUnit = opp.Business_Unit_BU__c;
        // w.subbusinessUnit = opp.Sub_Business_Unit__c;
        
        // w.closeDate = opp.CloseDate;
        // w.expectedCloseDate = opp.Expected_Close_Date__c;
        
        // w.createdDate = opp.CreatedDate;
        // w.lastModifiedDate = opp.LastModifiedDate;
        
        w.revenueProjectionStatus = 'No Revenue Projection';
        w.revenueProjectionIds = '';
        
        w.tcvUSD = convertToUSD(
            opp.TCV_in_Opportunity_Currency__c,
        opp.CurrencyIsoCode,
        currencyRates
            );
        
        w.acvUSD = convertToUSD(
            opp.ACV_in_Opportunity_Currency__c,
        opp.CurrencyIsoCode,
        currencyRates
            );
        
        return w;
    }
    
    /**
     * Assign Revenue Projection amount to correct quarter
     */
    private static void assignQuarterAmount(
        ExportWrapper wrapper,
    Revenue_Projection__c rp,
    Decimal amount
    ) {
        if (amount == null) {
            amount = 0;
        }
        
        switch on rp.FY_Type__c {
            when 'Current FY' {
                switch on rp.Fiscal_Quarter__c {
                    when 'Q1' {
                        wrapper.q1 += amount;
                    }
                    when 'Q2' {
                        wrapper.q2 += amount;
                    }
                    when 'Q3' {
                        wrapper.q3 += amount;
                    }
                    when 'Q4' {
                        wrapper.q4 += amount;
                    }
                }
            }
            when 'Next FY' {
                switch on rp.Fiscal_Quarter__c {
                    when 'Q1' {
                        wrapper.q5 += amount;
                    }
                    when 'Q2' {
                        wrapper.q6 += amount;
                    }
                    when 'Q3' {
                        wrapper.q7 += amount;
                    }
                    when 'Q4' {
                        wrapper.q8 += amount;
                    }
                }
            }
            when 'Extended' {
                wrapper.extended += amount;
            }
            when else {
                // Ignore unknown FY Type
            }
        }
    }
    
    /**
     * Convert any currency to USD
     */
    private static Decimal convertToUSD(
        Decimal amount,
    String currencyIsoCode,
    Map<String, Decimal> currencyRates
    ) {
        if (amount == null) {
            return 0;
        }
        
        if (currencyIsoCode == 'USD') {
            return amount;
        }
        
        Decimal sourceRate = currencyRates.get(currencyIsoCode);
        Decimal usdRate = currencyRates.get('USD');
        
        if (sourceRate == null || usdRate == null) {
            return amount;
        }
        
        return (amount / sourceRate) * usdRate;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPreviewDataView(
        Id opportunityId,
    Boolean exportAll,
    List<String> fieldApiNames,
    String columnsJson
    ) {
        RevenueProjectionExportQueueable queueable =
            new RevenueProjectionExportQueueable(
            opportunityId,
        fieldApiNames,
        exportAll,
        columnsJson,
        null,
        1
            );
        
        ExportBatch batch = queueable.getPreviewData();
        
        List<Map<String, Object>> previewRows = new List<Map<String, Object>>();
        
        for (Integer i = 0; i < batch.opportunities.size(); i++) {
            
            Map<String, Object> row =
                buildOpportunityValueMap(batch.opportunities[i]);
            
            row.putAll(
                buildRevenueProjectionValueMap(batch.wrappers[i])
                );
            
            previewRows.add(row);
        }
        
        return previewRows;
    }
}