public with sharing class RevenueProjectionExportController {
    
    public class ExportResponse {
        
        @AuraEnabled
        public String jobId;
        
        @AuraEnabled
        public String message;
    }
    
    public class OpportunityExportFieldWrapper {
        
        @AuraEnabled
        public String fieldLabel { get; set; }
        
        @AuraEnabled
        public String fieldApiName { get; set; }
        
        @AuraEnabled
        public String dataType { get; set; }
        
        @AuraEnabled
        public Boolean defaultSelected { get; set; }
        
        @AuraEnabled
        public Integer displayOrder { get; set; }
        
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OpportunityExportFieldWrapper> getExportFields() {
        
        List<OpportunityExportFieldWrapper> fields =
            new List<OpportunityExportFieldWrapper>();
        
        for (Opportunity_Export_Field__mdt md :
            [
            SELECT
                Field_Label__c,
                Field_API_Name__c,
                Data_Type__c,
                Default_Selected__c,
                Display_Order__c
            FROM Opportunity_Export_Field__mdt
            WHERE Is_Active__c = true
            ORDER BY Display_Order__c ASC
        ]
        ) {
            
            OpportunityExportFieldWrapper wrapper = new OpportunityExportFieldWrapper();
            
            wrapper.fieldLabel = md.Field_Label__c;
            wrapper.fieldApiName = md.Field_API_Name__c;
            wrapper.dataType = md.Data_Type__c;
            wrapper.defaultSelected = md.Default_Selected__c;
            wrapper.displayOrder = Integer.valueOf(md.Display_Order__c);
            
            fields.add(wrapper);
            
        }
        
        return fields;
        
    }
    
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>>  getPreviewData(
        Id opportunityId,
    Boolean exportAll,
    List<String> columns,
    String columnsJson
    ) {
        return RevenueProjectionExportQueueable.getPreviewDataView(
            opportunityId,
        exportAll,
        columns,
        columnsJson
            );
    }
    
    @AuraEnabled
    public static List<ContentVersion> getLatestExportFiles() {
        
        Datetime oneMinuteAgo = System.now().addMinutes(-1);
        
        
        return [
            SELECT Id,
            Title,
            ContentDocumentId,
            CreatedDate
            FROM ContentVersion
            WHERE CreatedById = :UserInfo.getUserId()
            AND Title LIKE 'RevenueProjectionExport_Part%'
            AND CreatedDate >= :oneMinuteAgo
            ORDER BY CreatedDate DESC
        ];
    }
    
    
    @AuraEnabled
    public static ExportResponse startExport(Id opportunityId, Boolean exportAll, List<String> columns, String exportColumns){
        System.debug('columns: '+columns);
        
        
        if(exportAll == null){
            exportAll = true;
        }
        
        Id jobId = System.enqueueJob(new RevenueProjectionExportQueueable(opportunityId, columns,exportAll, exportColumns,null,1));
        
        ExportResponse response = new ExportResponse();
        response.jobId = String.valueOf(jobId);
        response.message = exportAll
            ? 'Export of all Revenue Projections started successfully.'
            : 'Export started successfully.';
        
        return response;
    }
    
    @AuraEnabled(cacheable=false)
    public static AsyncApexJob getJobStatus(String jobId) {
        
        return [
            SELECT
            Id,
            Status,
            NumberOfErrors,
            JobItemsProcessed,
            TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=false)
    public static ContentVersion getLatestExportFile() {
        
        List<ContentVersion> files = [
            SELECT
            Id,
            Title,
            ContentDocumentId,
            CreatedDate
            FROM ContentVersion
            WHERE CreatedById = :UserInfo.getUserId()
            AND Title LIKE 'RevenueProjectionExport_%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return files.isEmpty() ? null : files[0];
    }
}