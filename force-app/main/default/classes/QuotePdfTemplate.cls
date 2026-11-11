public with sharing class QuotePdfTemplate {

    private static String cachedTemplate;
    private static String cachedStyles;

    public static String render(String quoteBody) {
        if (String.isBlank(quoteBody)) {
            quoteBody = '<p>Nincs megadott ajánlati leírás.</p>';
        }

        String template = loadTemplate();
        String styles = loadStyles();

        template = template.replace('{{PDF_CSS}}', styles);

        Date today = Date.today();
        String formattedDate =
            String.valueOf(today.day()).leftPad(2, '0') + '.' +
            String.valueOf(today.month()).leftPad(2, '0') + '.' +
            String.valueOf(today.year()) + '.';

        template = template.replace('{{DATE}}', formattedDate);
        template = template.replace('{{QUOTE_BODY}}', normalizeHtml(quoteBody));

        return template;
    }

    private static String loadTemplate() {
        if (cachedTemplate != null) return cachedTemplate;

        List<StaticResource> resources = [
            SELECT Body FROM StaticResource WHERE Name = 'SolarQuotePdfTemplate' LIMIT 1
        ];
        if (resources.isEmpty()) {
            throw new PdfTemplateException('Nem található a SolarQuotePdfTemplate Static Resource.');
        }
        cachedTemplate = resources[0].Body.toString();
        return cachedTemplate;
    }

    private static String loadStyles() {
        if (cachedStyles != null) return cachedStyles;

        List<StaticResource> resources = [
            SELECT Body FROM StaticResource WHERE Name = 'SolarQuotePdfStyles' LIMIT 1
        ];
        if (resources.isEmpty()) {
            throw new PdfTemplateException('Nem található a SolarQuotePdfStyles Static Resource.');
        }
        cachedStyles = resources[0].Body.toString();
        return cachedStyles;
    }

    private static String normalizeHtml(String html) {
        if (String.isBlank(html)) return '';

        String result = html;
        result = result.replaceAll('(?i)&nbsp;', '&#160;');
        result = result.replaceAll('&(?!amp;|lt;|gt;|quot;|apos;|#\\d+;|#x[0-9a-fA-F]+;)', '&amp;');
        result = result.replaceAll('(?i)<(br|hr)\\s*>', '<$1 />');
        result = result.replaceAll('(?i)<(img|col)([^>]*?)(?:\\s*/)?\\s*>', '<$1$2 />');
        return result;
    }

    public class PdfTemplateException extends Exception {}
}