public with sharing class QuoteCalculatorService {

    public class FlowInput {
        @InvocableVariable(required=true label='Lead ID' description='Az aktuális érdeklődő azonosítója')
        public String leadId;
    }

    public class FlowResult {
        @InvocableVariable(label='Sikeres-e a kalkuláció')
        public Boolean isSuccess;

        @InvocableVariable(label='Hibaüzenet, ha van')
        public String errorMessage;
    }

    @InvocableMethod(label='Napelem Ajánlat Előkalkuláció és Generálás' description='Moduláris kalkuláció, adatmentés és Prompt Template AI hívás.')
    public static List<FlowResult> generateQuote(List<FlowInput> inputs) {
        List<FlowResult> results = new List<FlowResult>();
        FlowResult res = new FlowResult();
        res.isSuccess = true;
        res.errorMessage = '';

        if (inputs == null || inputs.isEmpty()) {
            res.isSuccess = false;
            res.errorMessage = 'Nincs bemeneti adat.';
            results.add(res);
            return results;
        }

        Set<Id> leadIds = extractLeadIds(inputs);
        if (leadIds.isEmpty()) {
            res.isSuccess = false;
            res.errorMessage = 'Érvénytelen Lead ID.';
            results.add(res);
            return results;
        }

        Map<Id, Lead> leadsMap = QuoteDataSelector.getLeads(leadIds);
        if (leadsMap.isEmpty()) {
            res.isSuccess = false;
            res.errorMessage = 'A Lead nem található az adatbázisban.';
            results.add(res);
            return results;
        }

        List<Solar_Panel__c> panels = QuoteDataSelector.getPanels();
        List<Battery_Storage__c> batteries = QuoteDataSelector.getBatteries();
        List<Accessory__c> accessoriesList = QuoteDataSelector.getAccessories();
        List<Inverter__c> invertersList = QuoteDataSelector.getInverters();
        List<ProductCatalog__c> allAccessories = QuoteDataSelector.getProductCatalogsByGroup('Kiegészítők');
        
        ProductCatalog__c protBox = null;
        ProductCatalog__c cable = null;

        for (ProductCatalog__c pc : allAccessories) {
            if (pc.Name == null) continue;
            String nameLower = pc.Name.toLowerCase();
            if (protBox == null && (nameLower.contains('védelmi doboz') || nameLower.contains('túlfeszültség'))) {
                protBox = pc;
            } else if (cable == null && nameLower.contains('kábelezés')) {
                cable = pc;
            }
        }

        if (panels.isEmpty() || batteries.isEmpty() || protBox == null || cable == null) {
            res.isSuccess = false;
            res.errorMessage = 'DIAGNOSZTIKA: Hiányzó alapvető hardver elem a katalógusban (napelem, akkumulátor, védelmi doboz vagy kábelezés).';
            results.add(res);
            return results;
        }

        List<Quote__c> quotesToInsert = new List<Quote__c>();
        Map<Id, QuoteCalculationResult> leadContextMap = new Map<Id, QuoteCalculationResult>();

        for (Lead l : leadsMap.values()) {
            Decimal monthlyCons = (l.Havi_fogyasztas__c != null && l.Havi_fogyasztas__c > 0) ? l.Havi_fogyasztas__c : 300.0;
            String roofType = (l.Tetofedes_tipusa__c != null) ? l.Tetofedes_tipusa__c : 'Cseréptető';

            String targetPhase = QuoteCalculationEngine.validateLeadAndGetPhase(l);
            if (String.isBlank(targetPhase)) {
                targetPhase = (l.Fazisszam__c != null) ? l.Fazisszam__c : '1'; 
            }

            Decimal yearlyConsumption = monthlyCons * 12;
            Decimal panelkWp = (panels[0].Nevleges_teljesitmeny__c != null) ? panels[0].Nevleges_teljesitmeny__c / 1000.0 : 0.41;
            Decimal calculatedPanels = (yearlyConsumption * 1.15) / (panelkWp * 1050); 
            Integer panelCount = Integer.valueOf(Math.ceil(calculatedPanels));

            Inverter__c inverterDetails = QuoteCalculationEngine.findInverter(invertersList, targetPhase, panelCount * panelkWp);
            Accessory__c accessoryDetails = QuoteCalculationEngine.findAccessory(accessoriesList, roofType);

            if (inverterDetails == null && accessoryDetails == null) {
                res.isSuccess = false;
                res.errorMessage = 'DIAGNOSZTIKA: Nincs a katalógusban ' + targetPhase + '-fázisú inverter ehhez a teljesítményhez (' + (panelCount * panelkWp).setScale(2) + ' kWp), valamint a(z) "' + roofType + '" tetőfedéshez tartozó kiegészítő sem.';
                results.add(res);
                return results;
            } else if (inverterDetails == null) {
                res.isSuccess = false;
                res.errorMessage = 'DIAGNOSZTIKA: Nincs megfelelő ' + targetPhase + '-fázisú inverter a katalógusban a(z) ' + (panelCount * panelkWp).setScale(2) + ' kWp teljesítményű rendszerhez.';
                results.add(res);
                return results;
            } else if (accessoryDetails == null) {
                res.isSuccess = false;
                res.errorMessage = 'DIAGNOSZTIKA: A katalógusból hiányzik a(z) "' + roofType + '" tetőfedés-típushoz tartozó rögzítési kiegészítő.';
                results.add(res);
                return results;
            }

            QuoteCalculationResult calcResult = QuoteCalculationEngine.calculateMetrics(
                yearlyConsumption, l.PostalCode, panels[0], inverterDetails, batteries[0], 
                accessoryDetails, protBox, cable, panelCount, null
            );

            if (calcResult.isSuccess == false) {
                res.isSuccess = false;
                res.errorMessage = calcResult.errorMessage;
                results.add(res);
                return results;
            }

            leadContextMap.put(l.Id, calcResult);
            quotesToInsert.add(QuoteBuilder.buildQuote(l.Id, calcResult));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!leadIds.isEmpty()) {
                List<Quote__c> allOldQuotes = [
                    SELECT Id FROM Quote__c 
                    WHERE Lead__c IN :leadIds 
                    AND Status__c IN ('Piszkozat', 'Elküldve', 'Elfogadva')
                ];
                if (!allOldQuotes.isEmpty()) {
                    Database.delete(allOldQuotes, false);
                }
            }

            if (!quotesToInsert.isEmpty()) {
                insert quotesToInsert;

                List<QuoteItem__c> quoteItemsToInsert = new List<QuoteItem__c>();
                for (Quote__c q : quotesToInsert) {
                    QuoteCalculationResult ctx = leadContextMap.get(q.Lead__c);
                    if (ctx != null) {
                        QuoteBuilder.collectQuoteItems(q.Id, ctx, quoteItemsToInsert);
                    }
                }

                if (!quoteItemsToInsert.isEmpty()) {
                    insert quoteItemsToInsert;
                }
            }

        } catch (Exception e) {
            Database.rollback(sp);
            res.isSuccess = false;
            res.errorMessage = 'Hiba az adatbázis művelet során: ' + e.getMessage();
            results.add(res);
            return results;
        }

        results.add(res);
        return results;
    }

    private static Set<Id> extractLeadIds(List<FlowInput> inputs) {
        Set<Id> leadIds = new Set<Id>();
        for (FlowInput input : inputs) {
            if (input == null || String.isBlank(input.leadId)) continue;
            try {
                leadIds.add(Id.valueOf(input.leadId));
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Érvénytelen ID: ' + input.leadId);
            }
        }
        return leadIds;
    }
}