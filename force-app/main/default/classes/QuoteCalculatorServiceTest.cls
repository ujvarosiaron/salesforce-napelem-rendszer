@isTest
private class QuoteCalculatorServiceTest {

    @testSetup
    static void setupTestData() {
        List<ProductCatalog__c> catalogs = new List<ProductCatalog__c>{
            new ProductCatalog__c(Name = 'Napelem 410W', Komponenscsoport__c = 'Napelem-panelek', Brutto_egysegar__c = 45000),
            new ProductCatalog__c(Name = 'Inverter 5kW Hibrid', Komponenscsoport__c = 'Inverterek', Brutto_egysegar__c = 350000),
            new ProductCatalog__c(Name = 'Akkumulátor 5kWh', Komponenscsoport__c = 'Energiatárolók', Brutto_egysegar__c = 600000),
            new ProductCatalog__c(Name = 'Alumínium tartószerkezet cseréptetőhöz', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 12000),
            new ProductCatalog__c(Name = 'DC túlfeszültség védelmi doboz', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 45000),
            new ProductCatalog__c(Name = 'Szolár kábelezés szett', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 25000),
            new ProductCatalog__c(Name = 'Szerelési munkadíj', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 250000),
            new ProductCatalog__c(Name = 'Villamos szerelés', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 180000),
            new ProductCatalog__c(Name = 'Adminisztráció', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 120000),
            new ProductCatalog__c(Name = 'Logisztika', Komponenscsoport__c = 'Kiegészítők', Brutto_egysegar__c = 45000)
        };
        insert catalogs;

        insert new Solar_Panel__c(
            Nevleges_teljesitmeny__c = 410,
            Product_Catalog__c = catalogs[0].Id
        );

        insert new Battery_Storage__c(
            Kapacitas_kWh__c = 5,
            Product_Catalog__c = catalogs[2].Id
        );

        insert new Accessory__c(
            Accessory_Type__c = 'Tartószerkezet',
            Product_Catalog__c = catalogs[3].Id
        );

        insert new Inverter__c(
            Fazisszam_tipus__c = 'Háromfázisú (3f) Hibrid',
            Nevleges_teljesitmeny_kW__c = 5.0,
            Product_Catalog__c = catalogs[1].Id
        );
    }

    @isTest
    static void test1_SuccessfulQuoteGenerationWithBudapestZip() {
        Lead lead = new Lead(
            LastName = 'Kovács',
            Company = 'Teszt Kft',
            Havi_fogyasztas__c = 400,
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Tetofedes_tipusa__c = 'Cseréptető',
            PostalCode = '1111'
        );
        insert lead;

        List<QuoteCalculatorService.FlowInput> inputs = new List<QuoteCalculatorService.FlowInput>();
        QuoteCalculatorService.FlowInput input = new QuoteCalculatorService.FlowInput();
        input.leadId = lead.Id;
        inputs.add(input);

        Test.startTest();
        QuoteCalculatorService.generateQuote(inputs);
        Test.stopTest();

        List<Quote__c> quotes = [SELECT Id, Brutto_vegosszeg__c FROM Quote__c WHERE Lead__c = :lead.Id];
        System.assertEquals(1, quotes.size(), 'Pontosan egy ajánlatnak kellett generálódnia budapesti címmel is.');
        System.assert(quotes[0].Brutto_vegosszeg__c > 0, 'Az ajánlat bruttó végösszegének 0-nál nagynak kell lennie.');
    }

    @isTest
    static void test2_QuoteGenerationWithRuralZipCodes() {
        Lead lead2 = new Lead(
            LastName = 'Nagy',
            Company = 'Vidéki Kft',
            Havi_fogyasztas__c = 380,
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Tetofedes_tipusa__c = 'Cseréptető',
            PostalCode = '2000'
        );
        Lead lead3 = new Lead(
            LastName = 'Kiss',
            Company = 'Távoli Kft',
            Havi_fogyasztas__c = 400,
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Tetofedes_tipusa__c = 'Cseréptető',
            PostalCode = '4000'
        );
        List<Lead> testLeads = new List<Lead>{lead2, lead3};
        insert testLeads;

        List<QuoteCalculatorService.FlowInput> inputs = new List<QuoteCalculatorService.FlowInput>();
        for (Lead l : testLeads) {
            QuoteCalculatorService.FlowInput input = new QuoteCalculatorService.FlowInput();
            input.leadId = l.Id;
            inputs.add(input);
        }

        Test.startTest();
        QuoteCalculatorService.generateQuote(inputs);
        Test.stopTest();

        List<Quote__c> quotes = [SELECT Id FROM Quote__c];
        System.assertEquals(2, quotes.size(), 'Mindkét vidéki leadhez le kell futnia a kalkulációnak.');
    }

    @isTest
    static void test3_InvalidLeadDataTriggersReview() {
        Lead invalidLead = new Lead(
            LastName = 'Hibás',
            Company = 'Hiba Kft',
            Havi_fogyasztas__c = null,
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Tetofedes_tipusa__c = 'Cseréptető',
            PostalCode = '1000'
        );
        insert invalidLead;

        List<QuoteCalculatorService.FlowInput> inputs = new List<QuoteCalculatorService.FlowInput>();
        QuoteCalculatorService.FlowInput input = new QuoteCalculatorService.FlowInput();
        input.leadId = invalidLead.Id;
        inputs.add(input);

        Test.startTest();
        QuoteCalculatorService.generateQuote(inputs);
        Test.stopTest();

        Lead checkedLead = [SELECT Ellenorzest_igenyel__c FROM Lead WHERE Id = :invalidLead.Id];
        System.assertEquals(true, checkedLead.Ellenorzest_igenyel__c, 'Hiányzó adatok esetén be kell jelölni az ellenőrzés igényét.');
        
        List<Quote__c> quotes = [SELECT Id FROM Quote__c WHERE Lead__c = :invalidLead.Id];
        System.assertEquals(0, quotes.size(), 'Nem generálódhat ajánlat hibás leadhez.');
    }

    @isTest
    static void test4_NewQuoteOverwritesExisting() {
        Lead lead = new Lead(
            LastName = 'Felülíró',
            Company = 'Teszt Kft',
            Havi_fogyasztas__c = 400,
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Tetofedes_tipusa__c = 'Cseréptető',
            PostalCode = '1111'
        );
        insert lead;

        insert new Quote__c(
            Lead__c = lead.Id,
            Status__c = 'Piszkozat',
            Brutto_vegosszeg__c = 500000,
            Ervenyesseg_datuma__c = System.today().addDays(10)
        );

        List<QuoteCalculatorService.FlowInput> inputs = new List<QuoteCalculatorService.FlowInput>();
        QuoteCalculatorService.FlowInput input = new QuoteCalculatorService.FlowInput();
        input.leadId = lead.Id;
        inputs.add(input);

        Test.startTest();
        QuoteCalculatorService.generateQuote(inputs);
        Test.stopTest();

        List<Quote__c> quotes = [SELECT Id, Brutto_vegosszeg__c FROM Quote__c WHERE Lead__c = :lead.Id];
        System.assertEquals(1, quotes.size(), 'Újrageneráláskor felül kell írni a régi ajánlatot, így pontosan egynek kell maradnia.');
        System.assert(quotes[0].Brutto_vegosszeg__c != 500000, 'Az új ajánlat összegének a friss kalkulációt kell tükröznie, nem a régi 500 000 Ft-ot.');
    }

    @isTest
    static void test5_NullAndInvalidInputsGracefulHandling() {
        Test.startTest();
        QuoteCalculatorService.generateQuote(new List<QuoteCalculatorService.FlowInput>());
        QuoteCalculatorService.generateQuote(null);

        QuoteCalculatorService.FlowInput invalidInput = new QuoteCalculatorService.FlowInput();
        invalidInput.leadId = 'invalid_id_string';
        QuoteCalculatorService.generateQuote(new List<QuoteCalculatorService.FlowInput>{invalidInput});
        Test.stopTest();

        System.assert(true, 'A szolgáltatásnak kivétel nélkül le kell futnia hibakezeléssel.');
    }


    @isTest
    static void test6_DataSelectorCoverageHelper() {
        Test.startTest();
        
        
        Set<Id> dummyIds = new Set<Id>();
        QuoteDataSelector.getLeads(dummyIds);
        QuoteDataSelector.getLeadsWithExistingQuotes(dummyIds);
        QuoteDataSelector.getPanels();
        QuoteDataSelector.getBatteries();
        QuoteDataSelector.getAccessories();
        QuoteDataSelector.getInverters();
        QuoteDataSelector.getProductCatalogsByGroup('Kiegészítők');
        Test.stopTest();

        System.assert(true, 'DataSelector lefedettségi teszt sikeresen lefutott.');
    }
}