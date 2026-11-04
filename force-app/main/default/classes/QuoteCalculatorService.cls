public with sharing class QuoteCalculatorService {

    public class FlowInput {
        @InvocableVariable(required=true label='Lead ID' description='Az aktuális érdeklődő azonosítója')
        public String leadId;
    }

    @InvocableMethod(label='Napelem Ajánlat Előkalkuláció és Generálás' description='Moduláris, tiszta architektúrájú kalkuláció a Lead adatai alapján, felülíró logikával.')
    public static void generateQuote(List<FlowInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }

        // Bemeneti adatok feldolgozása: Lead ID-k kinyerése és érvénytelen formátumok kiszűrése
        Set<Id> leadIds = extractLeadIds(inputs);
        if (leadIds.isEmpty()) return;

        Map<Id, Lead> leadsMap = QuoteDataSelector.getLeads(leadIds);

        List<Solar_Panel__c> panels = QuoteDataSelector.getPanels();
        List<Battery_Storage__c> batteries = QuoteDataSelector.getBatteries();
        List<Accessory__c> accessoriesList = QuoteDataSelector.getAccessories();
        List<Inverter__c> invertersList = QuoteDataSelector.getInverters();

        // Csak a fizikai kiegészítőket (védelmi doboz, kábelezés) kérdezzük le a katalógusból
        List<ProductCatalog__c> allAccessories = QuoteDataSelector.getProductCatalogsByGroup('Kiegészítők');
        
        // Változók inicializálása a rendszerszintű kiegészítő elemek (védelmi doboz és kábelezés) tárolására
        ProductCatalog__c protBox = null;
        ProductCatalog__c cable = null;

        // Végigmegyünk a 'Kiegészítők' csoportba tartozó katalóguselemeken, hogy dinamikusan kiválasszuk a megfelelőket
        for (ProductCatalog__c pc : allAccessories) {
            if (pc.Name == null) continue; // Név hiányában átugorjuk a rekordot
            
            String nameLower = pc.Name.toLowerCase();
            // Ha még nem találtunk védelmi dobozt, és a név tartalmazza a kulcsszavakat, kiválasztjuk
            if (protBox == null && (nameLower.contains('védelmi doboz') || nameLower.contains('túlfeszültség'))) {
                protBox = pc;
            // Különben, ha még kábelezést sem találtunk, és a név alapján azonosítható, eltároljuk
            } else if (cable == null && nameLower.contains('kábelezés')) {
                cable = pc;
            }
        }

        // Listák és térképek előkészítése a kötegelt (bulkified) adatkezeléshez és a tranzakcióhoz
        List<Lead> leadsToUpdate = new List<Lead>();
        List<Quote__c> quotesToInsert = new List<Quote__c>();
        Map<Id, QuoteCalculationResult> leadContextMap = new Map<Id, QuoteCalculationResult>();

        // Iteráció az érintett érdeklődők (Lead) rekordjain
        for (Lead l : leadsMap.values()) {
            // Üzleti validáció: Ha hiányoznak a kötelező alapbeviteli adatok, a rendszer az Ellenorzest_igenyel__c mezőt true-ra állítja
            if (l.Havi_fogyasztas__c == null || l.Havi_fogyasztas__c <= 0 || l.Fazisszam__c == null || l.Tetofedes_tipusa__c == null) {
                l.Ellenorzest_igenyel__c = true; // Manuális felülvizsgálat megjelölése
                leadsToUpdate.add(l);
                continue; // Biztonságos továbblépés a következő Leadre, hibás ajánlat nem generálódik
            }

            // Katalógus-szintű integritásellenőrzés: Vizsgáljuk, hogy minden kötelező komponens (panel, akku, védelmi doboz, kábel) létezik-e és van-e érvényes ára
            if (panels.isEmpty() || panels[0].Nevleges_teljesitmeny__c == null || panels[0].Nevleges_teljesitmeny__c <= 0 ||
                panels[0].Product_Catalog__c == null || panels[0].Product_Catalog__r == null || panels[0].Product_Catalog__r.Brutto_egysegar__c == null ||
                batteries.isEmpty() || batteries[0].Kapacitas_kWh__c == null || batteries[0].Kapacitas_kWh__c <= 0 ||
                batteries[0].Product_Catalog__c == null || batteries[0].Product_Catalog__r == null || batteries[0].Product_Catalog__r.Brutto_egysegar__c == null ||
                protBox == null || protBox.Brutto_egysegar__c == null ||
                cable == null || cable.Brutto_egysegar__c == null) {
                l.Ellenorzest_igenyel__c = true; // Ha bármilyen termékadat hiányzik, ellenőrzési igényt jelzünk, mivel jelen adatok alapján műszakilag nem megvalósítható
                leadsToUpdate.add(l);
                continue;
            }

            // Fázisszám validálása (elavult vagy nem támogatott fázis esetén ellenőrzést kér)
            String targetPhase = QuoteCalculationEngine.validateLeadAndGetPhase(l);
            if (targetPhase == null) {
                l.Ellenorzest_igenyel__c = true;
                leadsToUpdate.add(l);
                continue;
            }


            // Éves villamosenergia-fogyasztás kiszámítása a havi fogyasztási adatból (kWh/év)
            Decimal yearlyConsumption = l.Havi_fogyasztas__c * 12;
            
            // Egy darab napelem-panel névleges teljesítményének átváltása Wp-ből kWp-be
            Decimal panelkWp = panels[0].Nevleges_teljesitmeny__c / 1000.0;
            
            // Szükséges panelek száma: az éves fogyasztás 15% biztonsági tartalékkal növelt értéke, 
            // elosztva egy panel éves becsült hozamával (0.44 kWp * 1050 kWh/kWp specifikus hozam)
            Decimal calculatedPanels = (yearlyConsumption * 1.15) / (panelkWp * 1050); 
            
            // Tizedes darabszám felfelé kerekítése egész darabra, mivel panelből csak egész szám rendelhető
            Integer panelCount = Integer.valueOf(Math.ceil(calculatedPanels));
            
            // A napelem mező összesített névleges csúcsteljesítménye kWp-ben (panel darabszám * egy panel teljesítménye)
            Decimal totalArraykWp = panelCount * panelkWp;

            // Inverter és tartószerkezet kiválasztása az optimális illeszkedés (1.0 - 1.2 DC/AC arány) alapján
            Inverter__c inverterDetails = QuoteCalculationEngine.findInverter(invertersList, targetPhase, totalArraykWp);
            Accessory__c accessoryDetails = QuoteCalculationEngine.findAccessory(accessoriesList, l.Tetofedes_tipusa__c);

            // Ha nincs megfelelő hardverkompatibilitás, ellenőrzési igényt jelzünk
            if (inverterDetails == null || accessoryDetails == null) {
                l.Ellenorzest_igenyel__c = true;
                leadsToUpdate.add(l);
                continue;
            }

            // Pénzügyi előkalkuláció és fix szolgáltatási/zónaalapú logisztikai díjak számítása
            QuoteCalculationResult calcResult = QuoteCalculationEngine.calculateMetrics(
                yearlyConsumption, l.PostalCode, panels[0], inverterDetails, batteries[0], 
                accessoryDetails, protBox, cable, panelCount, null
            );

            // Új árajánlat-tervezet objektum előkészítése a QuoteBuilder segédosztály hívásával
            // A metódus összekapcsolja az ajánlatot az aktuális Lead-del (l.Id) és beállítja a kalkulált bruttó végösszeget (calcResult.grossTotal)
            Quote__c newQuote = QuoteBuilder.buildQuote(l.Id, calcResult.grossTotal);
            
            // Hozzáadjuk a frissen létrehozott árajánlatot a beszúrásra váró gyűjtőlistához
            quotesToInsert.add(newQuote);
            
            // Eltároljuk egy Map-ben a Lead azonosítójához kapcsolva a teljes kalkulációs eredményt (calcResult),
            // hogy a későbbiekben (az ajánlati tételek / QuoteItem-ek generálásakor) könnyen hozzáférhessünk a részletes hardver- és árlistához
            leadContextMap.put(l.Id, calcResult);


        }

        // Adatbázis tranzakció indítása (Savepoint a biztonságos rollback érdekében)
        Savepoint sp = Database.setSavepoint();
        try {
            if (!leadsToUpdate.isEmpty()) {
                update leadsToUpdate;
            }

            // Felülírási logika: korábbi aktív (piszkozat vagy elküldött) ajánlatok törlése az újak beszúrása előtt
            if (!leadIds.isEmpty()) {
                List<Quote__c> oldQuotes = [
                    SELECT Id FROM Quote__c 
                    WHERE Lead__c IN :leadIds 
                    AND Status__c IN ('Piszkozat', 'Elküldve', 'Elfogadva')
                ];
                if (!oldQuotes.isEmpty()) {
                    delete oldQuotes;
                }
            }

            if (!quotesToInsert.isEmpty()) {
                insert quotesToInsert;

                // Ajánlati tételek (QuoteItem) gyűjtése és tömeges beszúrása
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
            // Robusztus hibakezelés: Tranzakció azonnali visszagörgetése hiba esetén
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'Hiba az ajánlatgenerálás során: ' + e.getMessage() + ' StackTrace: ' + e.getStackTraceString());
            throw e;
        }
    }

    // Segédmetódus: A Flow-ból érkező bemeneti adatokból kinyeri és normalizálja az érdeklődők egyedi azonosítóit (Lead ID)
    private static Set<Id> extractLeadIds(List<FlowInput> inputs) {
        Set<Id> leadIds = new Set<Id>(); // Set használata a duplikált azonosítók automatikus kiszűrésére
        
        for (FlowInput input : inputs) {
            // Null vagy üres bemenetek ellenőrzése és biztonságos átugrása
            if (input == null || String.isBlank(input.leadId)) continue;
            
            try {
                // Megpróbáljuk Salesfore Id típussá alakítani a szöveges azonosítót
                leadIds.add(Id.valueOf(input.leadId));
            } catch (Exception e) {
                // Hibakezelés: Ha a kapott string nem szabványos Salesforce ID formátumú, naplózzuk a figyelmeztetést, de a futást nem akasztjuk meg
                System.debug(LoggingLevel.WARN, 'Érvénytelen Lead ID formátum: ' + input.leadId);
            }
        }
        
        return leadIds; // Visszaadja a sikeresen kinyert, egyedi Lead azonosítók halmazát
    }
}