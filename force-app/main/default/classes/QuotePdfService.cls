public with sharing class QuotePdfService {

    public class PdfRequest {
        @InvocableVariable(required=true label='Lead ID')
        public Id leadId;

        @InvocableVariable(label='Quote Body')
        public String quoteBody;
    }

    public class PdfResult {
        @InvocableVariable(label='Generated ContentDocumentId')
        public Id contentDocId;
    }

    @InvocableMethod(label='Generate PDF & Save to Lead' category='Quote Automation')
    public static List<PdfResult> generateAndSavePdf(List<PdfRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<PdfResult>();
        }

        Set<Id> leadIds = new Set<Id>();
        for (PdfRequest req : requests) {
            if (req == null || req.leadId == null) {
                throw new PdfGenerationException('A PDF generálásához szükséges a Lead ID.');
            }
            leadIds.add(req.leadId);
        }

        Map<Id, Lead> existingLeads = new Map<Id, Lead>([
            SELECT Id, Formatted_Quote_Body__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        Map<Id, Lead> leadsToUpdate = new Map<Id, Lead>();
        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<Integer> requestIndexes = new List<Integer>();
        List<PdfResult> results = new List<PdfResult>();

        for (Integer i = 0; i < requests.size(); i++) {
            PdfRequest req = requests[i];
            Lead existingLead = existingLeads.get(req.leadId);
            String body = req.quoteBody;

            if (String.isBlank(body)) {
                body = existingLead != null ? existingLead.Formatted_Quote_Body__c : '';
            } else {
                leadsToUpdate.put(
                    req.leadId,
                    new Lead(Id = req.leadId, Formatted_Quote_Body__c = body)
                );
            }

            if (String.isBlank(body)) {
                body = '<p>Nincs megadott ajánlati leírás.</p>';
            }

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                String completeHtml = QuotePdfTemplate.render(body);
                pdfBlob = Blob.toPdf(completeHtml);
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Napelem_Arajanlat_' + System.now().format('yyyyMMdd_HHmmss') + '_' + String.valueOf(i + 1);
            cv.PathOnClient = 'Napelem_Arajanlat.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;

            versionsToInsert.add(cv);
            requestIndexes.add(i);
            results.add(new PdfResult());
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate.values();
        }

        insert versionsToInsert;

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : versionsToInsert) {
            versionIds.add(cv.Id);
        }

        Map<Id, ContentVersion> insertedVersions = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versionIds
        ]);

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (Integer i = 0; i < versionsToInsert.size(); i++) {
            ContentVersion cv = versionsToInsert[i];
            Integer requestIndex = requestIndexes[i];
            Id leadId = requests[requestIndex].leadId;

            ContentVersion insertedVersion = insertedVersions.get(cv.Id);
            if (insertedVersion == null || insertedVersion.ContentDocumentId == null) {
                throw new PdfGenerationException('Nem sikerült lekérni a létrehozott PDF fájl azonosítóját.');
            }

            Id contentDocId = insertedVersion.ContentDocumentId;
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = leadId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';

            linksToInsert.add(cdl);
            results[requestIndex].contentDocId = contentDocId;
        }

        insert linksToInsert;
        return results;
    }

    public class PdfGenerationException extends Exception {}
}