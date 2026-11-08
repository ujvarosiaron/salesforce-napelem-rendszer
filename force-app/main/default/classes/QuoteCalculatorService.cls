public with sharing class QuoteCalculatorService {

    public class FlowInput {
        @InvocableVariable(required=true label='Lead ID' description='Az aktuális érdeklődő azonosítója')
        public String leadId;
    }

    @InvocableMethod(label='Napelem Ajánlat Előkalkuláció és Generálás' description='Moduláris kalkuláció, adatmentés és Prompt Template AI hívás.')
    public static void generateQuote(List<FlowInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }

        Set<Id> leadIds = extractLeadIds(inputs);
        if (leadIds.isEmpty()) return;

        Map<Id, Lead> leadsMap = QuoteDataSelector.getLeads(leadIds);

        if (leadsMap.isEmpty()) {
            throw new AuraHandledException('HIBA: A Lead nem található az adatbázisban ezzel az ID-val: ' + leadIds);
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

        List<Quote__c> quotesToInsert = new List<Quote__c>();
        Map<Id, QuoteCalculationResult> leadContextMap = new Map<Id, QuoteCalculationResult>();

        for (Lead l : leadsMap.values()) {
            // Megengedőbb feltétel: ha valami hiányzik, alapértelmezett értéket adunk vagy logolunk, de nem omlik össze feltétlenül
            Decimal monthlyCons = (l.Havi_fogyasztas__c != null && l.Havi_fogyasztas__c > 0) ? l.Havi_fogyasztas__c : 300.0;
            String phase = (l.Fazisszam__c != null) ? l.Fazisszam__c : 'Háromfázisú (szabványos)';
            String roofType = (l.Tetofedes_tipusa__c != null) ? l.Tetofedes_tipusa__c : 'Cseréptető';

            if (panels.isEmpty() || batteries.isEmpty() || protBox == null || cable == null) {
                throw new AuraHandledException('DIAGNOSZTIKA: Hiányzó hardver elem a katalógusban.');
            }

            String targetPhase = QuoteCalculationEngine.validateLeadAndGetPhase(l);
            if (targetPhase == null) {
                targetPhase = '3'; // Biztonságos fallback
            }

            Decimal yearlyConsumption = monthlyCons * 12;
            Decimal panelkWp = (panels[0].Nevleges_teljesitmeny__c != null) ? panels[0].Nevleges_teljesitmeny__c / 1000.0 : 0.41;
            Decimal calculatedPanels = (yearlyConsumption * 1.15) / (panelkWp * 1050); 
            Integer panelCount = Integer.valueOf(Math.ceil(calculatedPanels));

            Inverter__c inverterDetails = QuoteCalculationEngine.findInverter(invertersList, targetPhase, panelCount * panelkWp);
            Accessory__c accessoryDetails = QuoteCalculationEngine.findAccessory(accessoriesList, roofType);

            if (inverterDetails == null || accessoryDetails == null) {
                throw new AuraHandledException('DIAGNOSZTIKA: Hiányzó hardver elem az inverter vagy kiegészítő keresésekor.');
            }

            QuoteCalculationResult calcResult = QuoteCalculationEngine.calculateMetrics(
                yearlyConsumption, l.PostalCode, panels[0], inverterDetails, batteries[0], 
                accessoryDetails, protBox, cable, panelCount, null
            );

            Quote__c newQuote = QuoteBuilder.buildQuote(l.Id, calcResult);
            quotesToInsert.add(newQuote);
            leadContextMap.put(l.Id, calcResult);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!leadIds.isEmpty()) {
                List<Quote__c> oldQuotes = [
                    SELECT Id FROM Quote__c 
                    WHERE Lead__c IN :leadIds 
                    AND Status__c IN ('Piszkozat', 'Elküldve', 'Elfogadva')
                ];
                if (!oldQuotes.isEmpty()) {
                    Database.delete(oldQuotes, false);
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
            System.debug(LoggingLevel.ERROR, 'Hiba az ajánlatgenerálás során: ' + e.getMessage());
            throw e;
        }
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