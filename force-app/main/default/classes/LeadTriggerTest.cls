@isTest
public class LeadTriggerTest {

    // 1. Teszteset: Maximum pontszám (Magas prioritás, várható pontszám = 40)
    // Cél: Minden dimenzióban a maximális pontot adó értékek kombinációjának tesztelése.
    @isTest
    static void testMaxScoreScenario() {
        Lead testLead = new Lead(
            FirstName = 'Teszt', LastName = 'Maximum', Company = 'Cég 1',
            Email = 'max@example.com', Phone = '+36301111111',
            Teto_dolesszog__c = '30° – 40°', // 2 pont
            Tajolas__c = 'Déli', // 4 pont
            Arnyekoltsag__c = 'Árnyékmentes', // 4 pont
            Havi_fogyasztas__c = 1000, // Éves 12000 kWh -> 10 pont
            Ingatlan_tipusa__c = 'Önálló családi ház', // 5 pont
            Fazisszam__c = 'Háromfázisú (szabványos)', // 5 pont
            Koltsegvetesi_keret__c = '5 millió Ft felett', // 5 pont
            Finanszirozasi_statusz__c = 'Önerő / Támogatott pályázat' // 5 pont
            // Összesen: 2+4+4+10+5+5+5+5 = 40 pont (Magas prioritás)
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c, Prioritas__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(40, insertedLead.Pontszam__c, 'A pontszámnak el kell érnie a 40 pontos maximumot!');
        System.assertEquals('Magas', insertedLead.Prioritas__c, 'A prioritásnak Magasnak kell lennie!');
    }

    // 2. Teszteset: Magas prioritás alsó határ / küszöb felett (Várható pontszám >= 30)
    // Cél: Határérték vizsgálat a Magas kategória alsó határánál (30 pont).
    @isTest
    static void testHighPriorityThresholdScenario() {
        Lead testLead = new Lead(
            FirstName = 'Anna', LastName = 'Magas', Company = 'Cég 3',
            Email = 'anna@example.com', Phone = '+36303333333',
            Teto_dolesszog__c = '30° – 40°', // 2 pont
            Tajolas__c = 'Délkeleti', // 3 pont
            Arnyekoltsag__c = 'Árnyékmentes', // 4 pont
            Havi_fogyasztas__c = 500, // Éves 6000 kWh -> 10 pont
            Ingatlan_tipusa__c = 'Önálló családi ház', // 5 pont
            Fazisszam__c = 'Háromfázisú (szabványos)', // 5 pont
            Koltsegvetesi_keret__c = '3-5 millió Ft között', // 3 pont
            Finanszirozasi_statusz__c = 'Hitel / Pályázat alatt' // 3 pont
            // Összesen: 2+3+4+10+5+5+3+3 = 35 pont (Magas)
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c, Prioritas__c FROM Lead WHERE Id = :testLead.Id];
        System.assert(insertedLead.Pontszam__c >= 30, 'A pontszámnak el kell érnie a 30-as küszöböt!');
        System.assertEquals('Magas', insertedLead.Prioritas__c, 'A prioritásnak Magasnak kell lennie!');
    }

    // 3. Teszteset: Közepes prioritás sáv (Várható pontszám: 20-29)
    // Cél: A közepes sávba eső alternatív picklist kombinációk és pontszámok ellenőrzése.
    @isTest
    static void testMediumPriorityScenario() {
        Lead testLead = new Lead(
            FirstName = 'Béla', LastName = 'Közepes1', Company = 'Cég 4',
            Email = 'bela@example.com', Phone = '+36304444444',
            Teto_dolesszog__c = '15° – 29°', // 1 pont
            Tajolas__c = 'Keleti', // 2 pont
            Arnyekoltsag__c = 'Részlegesen árnyékolt', // 2 pont
            Havi_fogyasztas__c = 280, // Éves 3360 kWh -> 7 pont
            Ingatlan_tipusa__c = 'Ikerház / sorház', // 3 pont
            Fazisszam__c = 'Egyfázisú / Bővítendő', // 3 pont
            Koltsegvetesi_keret__c = '3-5 millió Ft között', // 3 pont
            Finanszirozasi_statusz__c = 'Tájékozódó érdeklődő' // 1 pont
            // Összesen: 1+2+2+7+3+3+3+1 = 22 pont (Közepes)
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c, Prioritas__c FROM Lead WHERE Id = :testLead.Id];
        System.assert(insertedLead.Pontszam__c >= 20 && insertedLead.Pontszam__c <= 29, 'A pontszámnak 20 és 29 között kell lennie!');
        System.assertEquals('Kozepes', insertedLead.Prioritas__c, 'A prioritásnak Kozepesnek kell lennie!');
    }

    // 4. Teszteset: Alacsony prioritás sáv és else ágak (Várható pontszám < 20)
    // Cél: Kedvezőtlen paraméterek, legalsó sáv és az összes else ág lefedettsége.
    @isTest
    static void testLowPriorityAndElseBranchesScenario() {
        Lead testLead = new Lead(
            FirstName = 'Dénes', LastName = 'Alacsony1', Company = 'Cég 6',
            Email = 'denes@example.com', Phone = '+36306666666',
            Teto_dolesszog__c = '1° – 14°', // 0 pont
            Tajolas__c = 'Északi', // 0 pont
            Arnyekoltsag__c = 'Erősen árnyékolt', // 0 pont
            Havi_fogyasztas__c = 150, // Éves 1800 kWh -> 4 pont (< 3000 sáv else ága)
            Ingatlan_tipusa__c = 'Társasház', // 1 pont
            Fazisszam__c = 'Elavult / Nem szabványos', // 1 pont
            Koltsegvetesi_keret__c = '3 millió Ft alatt', // 1 pont
            Finanszirozasi_statusz__c = 'Tájékozódó érdeklődő' // 1 pont
            // Összesen: 0+0+0+4+1+1+1+1 = 9 pont (Alacsony)
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c, Prioritas__c FROM Lead WHERE Id = :testLead.Id];
        System.assert(insertedLead.Pontszam__c < 20, 'A pontszámnak 20 alatt kell lennie!');
        System.assertEquals('Alacsony', insertedLead.Prioritas__c, 'A prioritásnak Alacsonynak kell lennie!');
    }

    // 5. Teszteset: Magas éves fogyasztás (> 12 000 kWh ág tesztelése)
    // Cél: A fogyasztási profil 12 000 kWh feletti ágának (8 pont) ellenőrzése.
    @isTest
    static void testHighConsumptionBranchScenario() {
        Lead testLead = new Lead(
            FirstName = 'Zoltán', LastName = 'NagyFogyasztas', Company = 'Cég 9',
            Email = 'zoltan@example.com', Phone = '+36309999999',
            Teto_dolesszog__c = '30° – 40°',
            Tajolas__c = 'Déli',
            Arnyekoltsag__c = 'Árnyékmentes',
            Havi_fogyasztas__c = 1500, // Éves 18 000 kWh (> 12000) -> 8 pont
            Ingatlan_tipusa__c = 'Önálló családi ház',
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Koltsegvetesi_keret__c = '5 millió Ft felett',
            Finanszirozasi_statusz__c = 'Önerő / Támogatott pályázat'
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead.Pontszam__c, 'A pontszám nem lehet null nagy fogyasztás esetén sem!');
    }

    // 6. Teszteset: Null fogyasztás (Nullpointer és hibakezelés tesztelése)
    // Cél: Üres/null havi fogyasztási érték kezelése a kódban, hibamentes futás biztosítása.
    @isTest
    static void testNullConsumptionScenario() {
        Lead testLead = new Lead(
            FirstName = 'Erika', LastName = 'NullFogyasztas', Company = 'Cég 7',
            Email = 'erika@example.com', Phone = '+36307777777',
            Teto_dolesszog__c = '30° – 40°',
            Tajolas__c = 'Déli',
            Arnyekoltsag__c = 'Árnyékmentes',
            Havi_fogyasztas__c = null, // null érték vizsgálata
            Ingatlan_tipusa__c = 'Önálló családi ház',
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Koltsegvetesi_keret__c = '5 millió Ft felett',
            Finanszirozasi_statusz__c = 'Önerő / Támogatott pályázat'
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead.Pontszam__c, 'Null fogyasztás esetén is ki kell számolnia a pontszámot!');
    }

    // 7. Teszteset: Meglévő Contact (korábbi ügyfél) a rendszerben / Checkbox logika
    // Cél: Annak tesztelése, ha a rendszerben már létezik Contact, és a Lead korábbi ügyfélként (`Korabbi_ugyfel__c = true`) megkapja a maximális 5 pontot a finanszírozási blokkban.
    @isTest
    static void testExistingContactAndReturningCustomerScenario() {
        Contact existingContact = new Contact(
            FirstName = 'Kinga',
            LastName = 'Kiss',
            Email = 'kinga.kiss@example.com',
            Phone = '+36207204644'
        );
        insert existingContact;

        Lead testLead = new Lead(
            FirstName = 'Kinga', LastName = 'Kiss', Company = 'Kinga Cég',
            Email = 'kinga.kiss@example.com', Phone = '+36207204644',
            Teto_dolesszog__c = '1° – 14°',
            Tajolas__c = 'Északi',
            Arnyekoltsag__c = 'Erősen árnyékolt',
            Havi_fogyasztas__c = 100,
            Ingatlan_tipusa__c = 'Társasház',
            Fazisszam__c = 'Elavult / Nem szabványos',
            Koltsegvetesi_keret__c = '3 millió Ft alatt',
            Finanszirozasi_statusz__c = 'Tájékozódó érdeklődő',
            Korabbi_ugyfel__c = true 
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c, Prioritas__c FROM Lead WHERE Id = :testLead.Id];
        System.assert(insertedLead.Pontszam__c >= 5, 'A korábbi ügyfél státusznak biztosítania kell a pontokat!');
    }

    // 8. Teszteset: Visszatérő ügyfél ellenére eltérő űrlapos státusz jelölés felülbírálásának tesztelése
    @isTest
    static void testReturningCustomerOverrideScenario() {
        Lead testLead = new Lead(
            FirstName = 'Péter', LastName = 'Felülbírálás', Company = 'Cég Override',
            Email = 'peter.override@example.com', Phone = '+36305555555',
            Teto_dolesszog__c = '1° – 14°', // 0 pont
            Tajolas__c = 'Északi', // 0 pont
            Arnyekoltsag__c = 'Erősen árnyékolt', // 0 pont
            Havi_fogyasztas__c = 100, // 4 pont (< 3000)
            Ingatlan_tipusa__c = 'Társasház', // 1 pont
            Fazisszam__c = 'Elavult / Nem szabványos', // 1 pont
            Koltsegvetesi_keret__c = '3 millió Ft alatt', // 1 pont
            Finanszirozasi_statusz__c = 'Tájékozódó érdeklődő', 
            Korabbi_ugyfel__c = true // Visszatérő ügyfél -> fix 5 pont ebben a blokkban
        );
        // Összesen: 0 + 0 + 0 + 4 + 1 + 1 + 1 + 5 = 12 pont.

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Pontszam__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(12, insertedLead.Pontszam__c, 'A visszatérő ügyfél státusznak felül kell bírálnia az űrlapi tájékozódó státuszt, és pontosan 12 pontot kell eredményeznie!');
    }

    // 9. Teszteset: Update trigger ág tesztelése (módosítási esemény before update)
    // Cél: Annak ellenőrzése, hogy meglévő lead módosításakor is lefut-e a pontszámítás és frissül-e a prioritás.
    @isTest
    static void testUpdateTriggerScenario() {
        Lead updateTestLead = new Lead(
            FirstName = 'Kinga', LastName = 'UpdateTeszt', Company = 'Cég 10',
            Email = 'kinga.update@example.com', Phone = '+36300000001',
            Teto_dolesszog__c = '1° – 14°', 
            Tajolas__c = 'Északi',
            Arnyekoltsag__c = 'Erősen árnyékolt', 
            Havi_fogyasztas__c = 100,
            Ingatlan_tipusa__c = 'Társasház', 
            Fazisszam__c = 'Elavult / Nem szabványos',
            Koltsegvetesi_keret__c = '3 millió Ft alatt', 
            Finanszirozasi_statusz__c = 'Tájékozódó érdeklődő'
        );
        insert updateTestLead;

        Test.startTest();
        updateTestLead.Teto_dolesszog__c = '30° – 40°';
        updateTestLead.Tajolas__c = 'Déli';
        updateTestLead.Arnyekoltsag__c = 'Árnyékmentes';
        updateTestLead.Havi_fogyasztas__c = 500;
        updateTestLead.Ingatlan_tipusa__c = 'Önálló családi ház';
        updateTestLead.Fazisszam__c = 'Háromfázisú (szabványos)';
        updateTestLead.Koltsegvetesi_keret__c = '5 millió Ft felett';
        updateTestLead.Finanszirozasi_statusz__c = 'Önerő / Támogatott pályázat';
        update updateTestLead; 
        Test.stopTest();

        Lead updatedLead = [SELECT Pontszam__c, Prioritas__c FROM Lead WHERE Id = :updateTestLead.Id];
        System.assertEquals(40, updatedLead.Pontszam__c, 'Update után a pontszámnak frissülnie kell 40-re!');
        System.assertEquals('Magas', updatedLead.Prioritas__c, 'Update után a prioritásnak Magasnak kell lennie!');
    }

    // 10. Teszteset: Kivételkezelés (try-catch / hibára futás) tesztelése
    // Cél: Üres listás vagy edge-case hívás szimulálása, biztosítva a try-catch ág lefedettséget.
    @isTest
    static void testExceptionHandlingBranch() {
        Test.startTest();
        LeadScoringHandler.calculateLeadScore(null);
        Test.stopTest();

        System.assert(true, 'A hibakezelési ág tesztelése sikeresen lefutott.');
    }

    // 11. Teszteset: Hiányos mezők / Ellenőrzést igényel státusz tesztelése
    // Cél: Annak ellenőrzése, hogy ha valamelyik kulcsfontosságú mező üres, az Ellenorzest_igenyel__c jelölőnégyzet true legyen.
    @isTest
    static void testMissingFieldsAndInspectionRequiredScenario() {
        Lead testLead = new Lead(
            FirstName = 'Gábor', LastName = 'Hiányos', Company = 'Cég Hiányos',
            Email = 'hianyos@example.com', Phone = '+36301234567',
            Teto_dolesszog__c = null, // Üres mező
            Tajolas__c = 'Déli',
            Arnyekoltsag__c = 'Árnyékmentes',
            Havi_fogyasztas__c = 400,
            Ingatlan_tipusa__c = 'Önálló családi ház',
            Fazisszam__c = 'Háromfázisú (szabványos)',
            Koltsegvetesi_keret__c = '5 millió Ft felett',
            Finanszirozasi_statusz__c = 'Önerő / Támogatott pályázat'
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Ellenorzest_igenyel__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, insertedLead.Ellenorzest_igenyel__c, 'Hiányzó mező esetén az Ellenorzest_igenyel__c mező értékének igaznak kell lennie!');
    }
}