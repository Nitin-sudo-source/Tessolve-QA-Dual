public class RLIEmailQueueable implements Queueable {
    
    private Set<Id> oppIds;
    private Boolean isFromOpp;
    
    public RLIEmailQueueable(Set<Id> oppIds, Boolean isFromOpp) {
        this.oppIds = oppIds;
        this.isFromOpp = isFromOpp;
    }
    
    public void execute(QueueableContext context) {
        
        if (oppIds == null || oppIds.isEmpty()) return;
        
        // =========================
        // GET RLIs (ONLY pending)
        // =========================
        List<Resource_Line_Item__c> rlis = [
            SELECT Id, Name,
            Related_Opportunity__c,
            Selling_Rate__c,
            Sales_Selling_Rate__c,
            Account__r.Name,
            CurrencyIsoCode,
            Business_Unit__c,
            Sub_Business_Unit__c,
            Sub_Skills__c,
            Region__c,
            Number_of_Resources__c,
            Duration_Months__c,
            MSA_Customer__c,
            Is_Email_Send__c,
            Projected_Revenue__c,
            Status__c,
            Skill_Category_Matrix__r.Name,
            Experience1__r.Name,
            Engineer_Name__c,
            Related_Opportunity__r.StageName,
            Related_Opportunity__r.Opportunity_Id__c,
            Billing_Start_Date__c,
            Sales_Unit__c,
            Lost_Remarks__c,
            Lost_Reason__c,
            CreatedDate
            FROM Resource_Line_Item__c
            WHERE Related_Opportunity__c IN :oppIds
            AND LastModifiedDate = TODAY
        ];
        
        // =========================
        // GROUP BY OPPORTUNITY
        // =========================
        Map<Id, List<Resource_Line_Item__c>> oppMap = new Map<Id, List<Resource_Line_Item__c>>();
        
        if (rlis != null && !rlis.isEmpty()) {
            for (Resource_Line_Item__c r : rlis) {
                
                if (r != null 
                    && !oppMap.containsKey(r.Related_Opportunity__c) 
                    && r.Related_Opportunity__c != null 
                    && r.Related_Opportunity__r != null
                    && r.Related_Opportunity__r.StageName != null 
                    //&& !r.Related_Opportunity__r.StageName.equalsIgnoreCase('Prequalified')
                   ) {
                       
                       oppMap.put(r.Related_Opportunity__c, new List<Resource_Line_Item__c>());
                   }
                
                // ✅ SAFE ADD (prevents NPE)
                if (r != null 
                    && r.Related_Opportunity__c != null 
                    && oppMap.containsKey(r.Related_Opportunity__c)) {
                        
                        oppMap.get(r.Related_Opportunity__c).add(r);
                    }
            }
        }
        
        
        // =========================
        // FETCH OPPORTUNITIES
        // =========================
        Map<Id, Opportunity> oppMapData = new Map<Id, Opportunity>();
        
        if (oppMap != null && !oppMap.isEmpty()) {
            oppMapData = new Map<Id, Opportunity>(
                [SELECT Id,
                 Name,
                 CurrencyIsoCode,
                 Business_Unit_BU__c,
                 Owner.Email,
                 StageName,
                 Technical_Owner__r.Email,
                 
                 Opportunity_Id__c,
                 RecordType.Name,
                 Account_Name__c,
                 Owner.Name,
                 Execution_Location__c,
				 CreatedDate,
                 Total_Resource_requirement__c
                 
                 FROM Opportunity
                 WHERE Id IN :oppMap.keySet()]
            );
        }
        
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        Map<Integer, Id> indexToOpp = new Map<Integer, Id>();
        Integer index = 0;
        
        List<Contact> contList = new List<Contact>();
        contList = [SELECT Email, Business_Unit__c, Added_to_RLI_Email__c FROM Contact WHERE Email != null AND Business_Unit__c != null AND Added_to_RLI_Email__c =: True];
        System.debug('contList: '+contList.size());
        
        // =========================
        // BUILD EMAILS
        // =========================
        if (oppMap != null && !oppMap.isEmpty()) {
            
            for (Id oppId : oppMap.keySet()) {
                
                List<Resource_Line_Item__c> oppRLIs = oppMap.get(oppId);
                Opportunity opp = oppMapData.get(oppId);
                
                // ✅ skip if opp missing (prevents downstream NPE)
                if (opp == null) {
                    continue;
                }
                
                String body = buildEmailBody(oppRLIs, opp);
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                Set<String> emailSet = new Set<String>();
                
                
                Map<String, List<String>> businessUnitEmailMap = new Map<String, List<String>>();
                
                for(Contact cont : contList){
                    
                    if(String.isBlank(cont.Business_Unit__c) || String.isBlank(cont.Email)){
                        continue;
                    }
                    
                    if(!businessUnitEmailMap.containsKey(cont.Business_Unit__c)){
                        businessUnitEmailMap.put(
                            cont.Business_Unit__c,
                            new List<String>()
                        );
                    }
                    
                    businessUnitEmailMap.get(cont.Business_Unit__c).add(cont.Email.trim());
                }
                
                
                
                
                System.debug('BU Map => ' + businessUnitEmailMap);
                System.debug('Opp BU => [' + opp.Business_Unit_BU__c + ']');
                System.debug('Map Keys => ' + businessUnitEmailMap.keySet());
                System.debug('Contains Key => ' + businessUnitEmailMap.containsKey(opp.Business_Unit_BU__c));
                
                if(opp != null && (String.isNotBlank(opp.Business_Unit_BU__c) || opp.Business_Unit_BU__c != null) && businessUnitEmailMap.containsKey(opp.Business_Unit_BU__c)){
                    System.debug('Opp BU => ' + opp.Business_Unit_BU__c);
                    for(String email : businessUnitEmailMap.get(opp.Business_Unit_BU__c)){
                        if(String.isNotBlank(email) && email != null){
                            emailSet.add(email.trim());
                        }
                    }
                }
                
                //emailSet.addAll(buEmails);
                emailSet.addAll(new  Set<String>{'nitin.c@kvpcorp.com','navneet.s@kvpcorp.com'});
                
                // Technical Owner
                //if(!isFromOpp){
                if (opp.Technical_Owner__r != null &&
                    opp.Technical_Owner__r.Email != null) {
                        emailSet.add(opp.Technical_Owner__r.Email);
                    }
                //}
                
                // fallback
                if (emailSet.isEmpty()) {
                    emailSet.add(UserInfo.getUserEmail());
                }
                OrgWideEmailAddress owea;
                
                List<OrgWideEmailAddress> oweaList = [
                    SELECT Id, DisplayName
                    FROM OrgWideEmailAddress
                    WHERE DisplayName = 'Tessolve No-Reply'
                    LIMIT 1
                ];
                
                if(!oweaList.isEmpty()){
                    owea = oweaList[0];
                }
                if(owea != null){
                    System.debug('Org Wide Email Id: ' + owea.Id);
                    System.debug('Org Wide Display Name: ' + owea.DisplayName);
                    
                    mail.setOrgWideEmailAddressId(owea.Id);
                }
                
                System.debug('Recipients: ' + emailSet);
                mail.setToAddresses(new List<String>(emailSet));
                System.debug('Final To Addresses: ' + mail.getToAddresses());
                mail.setSubject('Resource Line Item for Opportunity '+ opp.Opportunity_Id__c);
                mail.setHtmlBody(body);
                
                emails.add(mail);
                
                indexToOpp.put(index, oppId);
                index++;
            }
        }
        
        // =========================
        // SEND EMAILS SAFELY
        // =========================
        List<Resource_Line_Item__c> updateList = new List<Resource_Line_Item__c>();
        
        if (!emails.isEmpty()) {
            try {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
                
                for (Integer i = 0; i < results.size(); i++) {
                    
                    Id oppId = indexToOpp.get(i);
                    
                    if (results[i].isSuccess()) {
                        
                        if (oppMap.containsKey(oppId)) {
                            for (Resource_Line_Item__c r : oppMap.get(oppId)) {
                                if (r != null) {
                                    //r.Is_Email_Send__c = true;
                                    r.Email_Sent_Date__c = System.today();
                                    updateList.add(r);
                                }
                            }
                        }
                        
                    } else {
                        for (Messaging.SendEmailError err : results[i].getErrors()) {
                            System.debug('Email failed for Opp ' + oppId + ': ' + err.getMessage());
                        }
                    }
                }
                
            } catch (Exception e) {
                System.debug('Email Exception: ' + e.getMessage());
            }
        }
        
        // =========================
        // UPDATE RECORDS SAFELY
        // =========================
        if (!updateList.isEmpty()) {
            try {
                update updateList;
            } catch (Exception e) {
                System.debug('Update failed: ' + e.getMessage());
            }
        }
    }
    
    public static List<OpportunityContactRole> getOpportunityMembers(Id opportunityId) {
        
        return [
            SELECT Id,
            ContactId,
            Contact.Name,
            Contact.Email,
            Contact.Phone,
            Role,
            IsPrimary
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            ORDER BY IsPrimary DESC, Contact.Name
        ];
    }
    
    
    private String buildEmailBody(List<Resource_Line_Item__c> rlis, Opportunity opp) {
        
        if (opp == null) {
            return 'Opportunity data not available.';
        }
        
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String oppLink = baseUrl + '/lightning/r/Opportunity/' + opp.Id + '/view';
        
        List<Resource_Line_Item__c> msaList = new List<Resource_Line_Item__c>();
        List<Resource_Line_Item__c> nonMsaList = new List<Resource_Line_Item__c>();
        
        for (Resource_Line_Item__c r : rlis) {
            if (r.MSA_Customer__c) msaList.add(r);
            else nonMsaList.add(r);
        }
        List<OpportunityContactRole> getContactList = getOpportunityMembers(opp.Id);
        List<String> contactNames = new List<String>();
        
        if(getContactList != null && !getContactList.isEmpty()){
            for(OpportunityContactRole ocr: getContactList){
                if(ocr.Contact.Name != null){
                    contactNames.add(ocr.Contact.Name);
                }
            }
        }
        String opportunityMembers = String.join(contactNames, ', ');
        
        String html = '';
        
        html += '<div style="font-family:Arial, sans-serif; font-size:13px; color:#333;">';
        
        html += '<p>Dear Team,</p>';
        html += '<p>Please find below the <b>Resource Line Item updates</b>:</p>';
        html += '<p><b>Customer Name: </b> ' +
            '<a href="' + oppLink + '">' + safe(opp.Account_Name__c) + '</a></p>';
        
        html += '<p><b>Opportunity: </b> ' +
            '<a href="' + oppLink + '">' + safe(opp.Name) + '</a></p>';
        
        html += '<p><b>Project Model Name: </b> ' +
            '<a href="' + oppLink + '">' + safe(opp.RecordType.Name) + '</a></p>';
        html += '<p><b>Execution Location: </b> ' +
            '<a href="' + oppLink + '">' + safe(opp.Execution_Location__c) + '</a></p>';
        html += '<p><b>Sales Manager Name: </b> ' +
            '<a href="' + oppLink + '">' + safe(opp.Owner.Name) + '</a></p>';
        html += '<p><b>Customer Contact: </b> ' +
            safe(opportunityMembers) +
            '</p>';
        Decimal Totalresources = opp.Total_Resource_requirement__c != null ? opp.Total_Resource_requirement__c : 0;
        html += '<p><b>Total Resource Requirement: </b> ' +
            String.valueof(Totalresources) +
            '</p>';
        
        html += '<p><b>Opportunity Created Date: </b> ' +
            Opp.CreatedDate.format('dd-MM-yyyy') +
            '</p>';
        
        // =========================
        // NON-MSA TABLE
        // =========================
        if (!nonMsaList.isEmpty()) {
            
            html += '<h3 style="color:#d9534f;">Non-MSA (Rate Change)</h3>';
            
            html += '<table style="width:100%; border-collapse:collapse; background:#ffffff;">';
            
            html += '<tr style="background:#f5f5f5; text-align:left;">' +
                '<th style="border:1px solid #ddd; padding:8px;">RLI</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Status</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Skill Category Matrix</th>'+
                //'<th style="border:1px solid #ddd; padding:8px;">Skill</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Exp</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Region</th>' +
                //   '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Selling</th>' +
                //  '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Modified</th>' +
                // '<th style="border:1px solid #ddd; padding:8px;">Drop %</th>' +
                //'<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Projected Revenue</th>' +
                // '<th style="border:1px solid #ddd; padding:8px;">Impact</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Business Unit</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Sub Business Unit</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Sub Skills</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Number of Resources</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Resource Name</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Billing Start Date</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Duration In Months</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Sales Unit</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">RLI CreatedDate</th>' +
                '</tr>';
            
            for (Resource_Line_Item__c r : nonMsaList) {
                
                Decimal selling = r.Selling_Rate__c != null ? r.Selling_Rate__c : 0;
                Decimal modified = r.Sales_Selling_Rate__c != null ? r.Sales_Selling_Rate__c : 0;
                
                Decimal drop = selling > 0 ? ((selling - modified)/selling)*100 : 0;
                
                Decimal resources = r.Number_of_Resources__c != null ? r.Number_of_Resources__c : 0;
                Decimal duration = r.Duration_Months__c != null ? r.Duration_Months__c : 0;
                
                Decimal projectedRevenue = r.Projected_Revenue__c;
                Decimal impact = (selling - modified) * resources * duration;
                
                String symbol = getCurrencySymbol(opp.CurrencyIsoCode);
                String link = baseUrl + '/lightning/r/Resource_Line_Item__c/' + r.Id + '/view';
                
                html += '<tr style="background:#ffffff; text-align:left;">';
                
                html += '<td style="border:1px solid #ddd; padding:8px;">' +
                    '<a href="'+link+'">'+safe(r.Name)+'</a></td>';
                
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Status__c)+'</td>';
                // html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sub_Skills__c)+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Skill_Category_Matrix__r !=null ? r.Skill_Category_Matrix__r.Name : null )+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Experience1__r != null ? r.Experience1__r.Name : null)+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Region__c)+'</td>';
                
                //   html += '<td style="border:1px solid #ddd; padding:8px; text-align:right !important;">'+symbol+' '+selling.setScale(2)+'</td>';
                //    html += '<td style="border:1px solid #ddd; padding:8px; text-align:right !important;">'+symbol+' '+modified.setScale(2)+'</td>';
                
                // html += '<td style="border:1px solid #ddd; padding:8px; text-align:center;"><b>'+drop.setScale(2)+'%</b></td>';
                
               // html += '<td style="border:1px solid #ddd; padding:8px; text-align:right !important;"><b>'+symbol+' '+(projectedRevenue != null ? projectedRevenue : 0).setScale(2)
                   // +'</b></td>';
                
                // html += '<td style="border:1px solid #ddd; padding:8px; text-align:right; color:#d9534f;"><b>'+symbol+' '+impact.setScale(2)+'</b></td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Business_Unit__c)+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sub_Business_Unit__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sub_Skills__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(String.valueOf(resources))+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Engineer_Name__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">' +
                    (r.Billing_Start_Date__c != null
                     ? DateTime.newInstance(r.Billing_Start_Date__c, Time.newInstance(0,0,0,0))
                     .format('dd-MM-yyyy')
                     : '') +
                    '</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(String.valueOf(r.Duration_Months__c))+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sales_Unit__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">' +
                    r.CreatedDate.format('dd-MM-yyyy') +
                    '</td>';
                html += '</tr>';
            }
            
            html += '</table><br/>';
        }
        
        // =========================
        // MSA TABLE
        // =========================
        if (!msaList.isEmpty()) {
            
            html += '<h3 style="color:#0275d8;">MSA (Standard Rates)</h3>';
            
            html += '<table style="width:100%; border-collapse:collapse; background:#ffffff;">';
            
            html += '<tr style="background:#f5f5f5;text-align:left;">' +
                '<th style="border:1px solid #ddd; padding:8px;">RLI</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Status</th>' +
                //  '<th style="border:1px solid #ddd; padding:8px;text-align:center;">Skill</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Skill Category Matrix</th>'+
                '<th style="border:1px solid #ddd; padding:8px;">Exp</th>' +
                '<th style="border:1px solid #ddd; padding:8px;">Region</th>' +
                //  '<th style="border:1px solid #ddd; padding:8px; text-align:right !important;">Selling Rate</th>' +
                // '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Projected Revenue</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Business Unit</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Sub Business Unit</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Sub Skills</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Number of Resources</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Resource Name</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Billing Start Date</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Duration In Months</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">Sales Unit</th>' +
                '<th style="border:1px solid #ddd; padding:8px;text-align:right !important;">RLI CreatedDate</th>' +
                
                '</tr>';
            
            for (Resource_Line_Item__c r : msaList) {
                
                String symbol = getCurrencySymbol(opp.CurrencyIsoCode);
                String link = baseUrl + '/lightning/r/Resource_Line_Item__c/' + r.Id + '/view';
                
                html += '<tr>';
                
                html += '<td style="border:1px solid #ddd; padding:8px; text-align:left;">' +
                    '<a href="'+link+'">'+safe(r.Name)+'</a></td>';
                
                html += '<td style="border:1px solid #ddd; padding:8px; text-align:left;">'+safe(r.Status__c)+'</td>';
                //html += '<td style="border:1px solid #ddd; padding:8px; text-align:center;">'+safe(r.Sub_Skills__c)+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Skill_Category_Matrix__r !=null ? r.Skill_Category_Matrix__r.Name : null )+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px; text-align:left;">'+safe(r.Experience1__r.Name )+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px; text-align:left;">'+safe(r.Region__c)+'</td>';
                
                //  html += '<td style="border:1px solid #ddd; padding:8px; text-align:right !important;">'+symbol+' '+(r.Selling_Rate__c != null ? r.Selling_Rate__c : 0).setScale(2)+'</td>';
                //  html += '<td style="border:1px solid #ddd; padding:8px; text-align:right !important;"><b>'+symbol+' '+r.Projected_Revenue__c.setScale(2)+'</b></td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Business_Unit__c)+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sub_Business_Unit__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sub_Skills__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(String.valueOf(r.Number_of_Resources__c))+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Engineer_Name__c)+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">' +
                    (r.Billing_Start_Date__c != null
                     ? DateTime.newInstance(r.Billing_Start_Date__c, Time.newInstance(0,0,0,0))
                     .format('dd-MM-yyyy')
                     : '') +
                    '</td>';               
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(String.valueOf(r.Duration_Months__c))+'</td>'; 
                html += '<td style="border:1px solid #ddd; padding:8px;">'+safe(r.Sales_Unit__c)+'</td>';
                html += '<td style="border:1px solid #ddd; padding:8px;">' +
                    r.CreatedDate.format('dd-MM-yyyy') +
                    '</td>';
                
                
                html += '</tr>';
            }
            
            html += '</table>';
        }
        
        html += '<br/><p>Regards,<br/>Salesforce System</p>';
        html += '</div>';
        
        return html;
    }
    
    private String getCurrencySymbol(String iso) {
        if (iso == 'INR') return '₹';
        if (iso == 'USD') return '$';
        if (iso == 'EUR') return '€';
        if (iso == 'GBP') return '£';
        if (iso == 'JPY') return '¥';
        return iso != null ? iso : '';
    }
    
    // =========================
    // HELPER
    // =========================
    private String safe(String val){
        return val == null ? '' : val;
    }
}