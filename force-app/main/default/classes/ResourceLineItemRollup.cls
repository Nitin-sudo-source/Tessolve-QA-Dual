public with sharing class ResourceLineItemRollup {
    
    public static void rollupData(Set<Id> oppIds){
        
        if(oppIds == null || oppIds.isEmpty()){
            return;
        }
        
        try {
            
            Map<Id, Decimal> lostMap = new Map<Id, Decimal>();
            Map<Id, Decimal> fulfilledMap = new Map<Id, Decimal>();
            Map<Id, Decimal> pendingMap = new Map<Id, Decimal>();

            
            // ✅ Get Opportunity data (SOURCE OF TRUTH)
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
                SELECT Id,
                TCV_in_Opportunity_Currency__c,
                TCV_in_USD__c,
				Total_Resource_requirement__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ]);
            
            // -------------------- RLI --------------------
            List<Resource_Line_Item__c> rliList = [
                SELECT Id, Related_Opportunity__c, Projected_Revenue__c, Status__c, Number_of_Resources__c, Related_Opportunity__r.Total_Resource_Requirement__c
                FROM Resource_Line_Item__c
                WHERE Related_Opportunity__c IN :oppIds
            ];
            
            for(Resource_Line_Item__c rli : rliList){
                
                if(rli.Related_Opportunity__c == null) continue;
                
                Id oppId = rli.Related_Opportunity__c;
                
                Decimal revenue = rli.Projected_Revenue__c == null ? 0 : rli.Projected_Revenue__c;
                
                if(rli.Status__c == 'Resource Fulfilled'){
                    fulfilledMap.put(oppId,
                                     (fulfilledMap.containsKey(oppId) ? fulfilledMap.get(oppId) : 0) + revenue
                                    );
                }
                else if(rli.Status__c == 'Lost'){
                    lostMap.put(oppId,
                                (lostMap.containsKey(oppId) ? lostMap.get(oppId) : 0) + revenue
                               );
                }
                else {
                    pendingMap.put(oppId,
                                   (pendingMap.containsKey(oppId) ? pendingMap.get(oppId) : 0) + revenue
                                  );
                }
            }
            

            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            
            for(Id oppId : oppIds){
                
                Opportunity opp = oppMap.get(oppId);
                if(opp == null) continue;
                
                Decimal totalInr = opp.TCV_in_Opportunity_Currency__c;
                Decimal totalUsd = opp.TCV_in_USD__c;
                
                Decimal fulfilled = fulfilledMap.get(oppId) == null ? 0 : fulfilledMap.get(oppId);
                Decimal lost      = lostMap.get(oppId) == null ? 0 : lostMap.get(oppId);
                Decimal pending   = pendingMap.get(oppId) == null ? 0 : pendingMap.get(oppId);
                
                Decimal fulfilledUSD;
                Decimal lostUSD;
                Decimal pendingUSD;
                
                // ✅ PROPORTIONAL DISTRIBUTION (KEY FIX)
               /* if(totalInr != null && totalInr != 0 && totalUsd != null){
                    
                    fulfilledUSD = (fulfilled / totalInr) * totalUsd;
                    lostUSD      = (lost / totalInr) * totalUsd;
                    pendingUSD   = (pending / totalInr) * totalUsd;
                    
                    // ✅ Adjust rounding diff
                    Decimal diff = totalUsd - (fulfilledUSD + lostUSD + pendingUSD);
                    pendingUSD += diff;
}*/
                if(totalInr != null && totalInr != 0 && totalUsd != null){
                    
                    Decimal conversionRate = totalUsd / totalInr;
                    
                    fulfilledUSD = fulfilled * conversionRate;
                    lostUSD      = lost * conversionRate;
                    pendingUSD   = pending * conversionRate;
                }
                
                
                oppsToUpdate.add(new Opportunity(
                    Id = oppId,
                    
                    Total_Lost__c = lost.setScale(2),
                    Total_Fulfilled__c = fulfilled.setScale(2),
                    Total_Pending__c = pending.setScale(2),
                   // Total_Resource_Requirement__c =  resourceCountMap.get(oppId) == null ? 0 : resourceCountMap.get(oppId),
                    Total_Fulfilled_USD__c = fulfilledUSD != null ? fulfilledUSD.setScale(2) : null,
                    Total_Lost_USD__c = lostUSD != null ? lostUSD.setScale(2) : null,
                    Total_Pending_USD__c = pendingUSD != null ? pendingUSD.setScale(2) : null
                ));
                
            }
            
            if(!oppsToUpdate.isEmpty()){
                Database.update(oppsToUpdate, false);
            }
            
        } catch (Exception ex) {
            System.debug('Unexpected error in rollupData: ' + ex.getMessage());
            throw ex;
        }
    }
}