public class LeadScoringHandler {


    
public static void calculateLeadScore(List<Lead> leadList) {
        if (leadList == null || leadList.isEmpty()) {
            return;
        }
        
        for (Lead l : leadList) {
            try {
                if (l.Teto_dolesszog__c == null || l.Tajolas__c == null || l.Arnyekoltsag__c == null || 
                    l.Havi_fogyasztas__c == null || l.Ingatlan_tipusa__c == null || l.Fazisszam__c == null || 
                    l.Koltsegvetesi_keret__c == null || l.Finanszirozasi_statusz__c == null) {
                    l.Ellenorzest_igenyel__c = true;
                } else {
                    l.Ellenorzest_igenyel__c = false;
                }

                Integer totalScore = 0;
                
                totalScore += calculateRoofScore(l);
                totalScore += calculateConsumptionScore(l);
                totalScore += calculateInfrastructureScore(l);
                totalScore += calculateFinancialAndClientScore(l);
                
                if (totalScore > 40) {
                    totalScore = 40;
                }
                l.Pontszam__c = totalScore;
                
                l.Prioritas__c = determinePriority(totalScore);

            } catch (Exception e) {
                l.addError('Hiba történt a lead pontszámának kiszámítása során: ' + e.getMessage());
            }
        }
    }



    
    private static Integer calculateRoofScore(Lead l) {
        Integer score = 0;
        
        if (l.Teto_dolesszog__c == '30° – 40°') {
            score += 2;
        } else if (l.Teto_dolesszog__c == '15° – 29°' || l.Teto_dolesszog__c == '41° – 50°') {
            score += 1;
        }
        
        if (l.Tajolas__c == 'Déli') {
            score += 4;
        } else if (l.Tajolas__c == 'Délkeleti' || l.Tajolas__c == 'Délnyugati') {
            score += 3;
        } else if (l.Tajolas__c == 'Keleti' || l.Tajolas__c == 'Nyugati') {
            score += 2;
        }
        
        if (l.Arnyekoltsag__c == 'Árnyékmentes') {
            score += 4;
        } else if (l.Arnyekoltsag__c == 'Részlegesen árnyékolt') {
            score += 2;
        }
        
        return score;
    }

    
    private static Integer calculateConsumptionScore(Lead l) {
        if (l.Havi_fogyasztas__c == null) {
            return 0;
        }
        Decimal annualConsumption = l.Havi_fogyasztas__c * 12; 
        if (annualConsumption >= 4000 && annualConsumption <= 12000) {
            return 10;
        } else if (annualConsumption > 12000) {
            return 8;
        } else if (annualConsumption >= 3000 && annualConsumption < 4000) {
            return 7;
        } else {
            return 4;
        }
    }



    
    private static Integer calculateInfrastructureScore(Lead l) {
        Integer score = 0;
        
        if (l.Ingatlan_tipusa__c == 'Önálló családi ház') {
            score += 5;
        } else if (l.Ingatlan_tipusa__c == 'Ikerház / sorház') {
            score += 3;
        } else if (l.Ingatlan_tipusa__c == 'Társasház') {
            score += 1;
        }
        
        if (l.Fazisszam__c == 'Háromfázisú (szabványos)') {
            score += 5;
        } else if (l.Fazisszam__c == 'Egyfázisú / Bővítendő') {
            score += 3;
        } else {
            score += 1;
        }
        return score;
    }




    
    private static Integer calculateFinancialAndClientScore(Lead l) {
        Integer score = 0;
        
        // Költségvetési keret vizsgálata (max 5 pont)
        if (l.Koltsegvetesi_keret__c == '5 millió Ft felett') {
            score += 5;
        } else if (l.Koltsegvetesi_keret__c == '3-5 millió Ft között') {
            score += 3;
        } else {
            score += 1;
        }
        
        // Finanszírozási státusz vagy Korábbi ügyfél vizsgálata (max 5 pont)
        // Ha korábbi ügyfél, automatikusan megkapja a max 5 pontot (felülbírálja az űrlapi státuszt)
        if (l.Korabbi_ugyfel__c == true) {
            score += 5;
        } else if (l.Finanszirozasi_statusz__c == 'Önerő / Támogatott pályázat') {
            score += 5;
        } else if (l.Finanszirozasi_statusz__c == 'Hitel / Pályázat alatt') {
            score += 3;
        } else {
            score += 1; // Tájékozódó érdeklődő vagy üres
        }
        
        return score;
    }


    

    
    private static String determinePriority(Integer totalScore) {
        if (totalScore >= 30) {
            return 'Magas';
        } else if (totalScore >= 20 && totalScore <= 29) {
            return 'Kozepes';
        } else {
            return 'Alacsony';
        }
    }



}