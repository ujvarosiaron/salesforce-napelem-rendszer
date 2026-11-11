public with sharing class QuoteEmailService {

    // IDE írd be az ellenőrzött Organization-Wide Email Address címét (nem gmail.com).
    // Ha üres, vagy nincs ilyen ellenőrzött cím, a levél a felhasználó címéről megy, mint eddig.
    private static final String FROM_ADDRESS = 'IDE_IRD_A_CIMET@pelda.hu';

    @AuraEnabled(cacheable=true)
    public static String getAttachmentName(Id contentDocumentId) {
        if (contentDocumentId == null) {
            return null;
        }
        List<ContentDocument> docs = [
            SELECT Title, FileExtension
            FROM ContentDocument
            WHERE Id = :contentDocumentId
            LIMIT 1
        ];
        if (docs.isEmpty()) {
            return null;
        }
        String ext = String.isNotBlank(docs[0].FileExtension) ? '.' + docs[0].FileExtension : '';
        return docs[0].Title + ext;
    }

    @AuraEnabled
    public static void sendQuoteEmail(
        Id leadId,
        String toAddress,
        String subject,
        String htmlBody,
        Id contentDocumentId
    ) {
        if (leadId == null) {
            throwAura('Hiányzik az azonosító (Lead vagy Quote ID).');
        }
        if (String.isBlank(toAddress)) {
            throwAura('Adj meg címzettet.');
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress.trim() });
        mail.setSubject(String.isBlank(subject) ? '(nincs tárgy)' : subject);
        mail.setHtmlBody(String.isBlank(htmlBody) ? '' : htmlBody);

        // A TargetObjectId csak Lead azonosítóra állítható be. Az ellenőrzést előre végezzük el,
        // mert a beállítás maga nem dob kivételt, a hiba csak a küldéskor jelentkezne.
        if (leadId.getSObjectType() == Schema.Lead.SObjectType) {
            mail.setTargetObjectId(leadId);
            mail.setTreatTargetObjectAsRecipient(false);
            mail.setSaveAsActivity(true);
        }

        // Ellenőrzött feladó cím (Organization-Wide Email Address), ha van
        if (String.isNotBlank(FROM_ADDRESS)) {
            List<OrgWideEmailAddress> senders = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = :FROM_ADDRESS
                LIMIT 1
            ];
            if (!senders.isEmpty()) {
                mail.setOrgWideEmailAddressId(senders[0].Id);
            }
        }

        // A PDF valódi mellékletként
        if (contentDocumentId != null) {
            List<ContentVersion> versions = [
                SELECT Id
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
                LIMIT 1
            ];
            if (!versions.isEmpty()) {
                mail.setEntityAttachments(new List<Id>{ versions[0].Id });
            }
        }

        Messaging.SendEmailResult[] results;
        try {
            results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            throwAura('Az e-mail küldése sikertelen: ' + e.getMessage());
        }

        if (results == null || results.isEmpty() || !results[0].isSuccess()) {
            String detail = (results != null && !results.isEmpty() && !results[0].getErrors().isEmpty())
                ? results[0].getErrors()[0].getMessage()
                : 'ismeretlen hiba';
            throwAura('Az e-mail küldése sikertelen: ' + detail);
        }

        // A sikeres küldés után az árajánlat státuszának és időbélyegének frissítése
        markQuoteAsSent(leadId);
    }

    // A legfrissebb árajánlat megkeresése a kapott azonosító alapján (Lead vagy Quote ID),
    // majd a státusz és az elküldés időpontjának rögzítése. Hiba esetén látható üzenetet adunk.
    // A metódus Lightning komponensből is hívható (például a szabványos e-mail szerkesztő megnyitásakor).
    @AuraEnabled
    public static void markQuoteAsSent(Id recordId) {
        if (recordId == null) {
            throwAura('Hiányzik az azonosító (Lead vagy Quote ID).');
        }

        List<Quote__c> quotes = [
            SELECT Id, Status__c, Ajanlat_elkuldvenek_idopontja__c
            FROM Quote__c
            WHERE Lead__c = :recordId OR Id = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (quotes.isEmpty()) {
            throwAura('Nem található árajánlat ehhez a rekordhoz (ID: ' + recordId + '), ezért az állapota nem frissült.');
        }

        Quote__c q = quotes[0];
        q.Status__c = 'Elküldve';
        q.Ajanlat_elkuldvenek_idopontja__c = System.now();

        Database.SaveResult sr = Database.update(q, false);
        if (!sr.isSuccess()) {
            throwAura('Az árajánlat frissítése sikertelen: ' + sr.getErrors()[0].getMessage());
        }
    }

    private static void throwAura(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        throw ex;
    }
}