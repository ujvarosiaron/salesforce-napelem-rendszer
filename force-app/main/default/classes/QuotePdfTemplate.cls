public with sharing class QuotePdfTemplate {

    private static String cachedTemplate;
    private static String cachedStyles;

    /**
     * A teljes PDF HTML tartalmának előállítása.
     *
     * @param quoteBody Az LWC-ből érkező szerkesztett HTML.
     * @return A PDF-generáláshoz előkészített HTML.
     */
    public static String render(String quoteBody) {

        if (String.isBlank(quoteBody)) {
            quoteBody = '<p>Nincs megadott ajánlati leírás.</p>';
        }

        String template = loadTemplate();
        String styles = loadStyles();

        // A CSS behelyettesítése a HTML dokumentum head részébe.
        template = template.replace('{{PDF_CSS}}', styles);

        // Dátum előállítása: DD.MM.YYYY.
        Date today = Date.today();

        String formattedDate =
            String.valueOf(today.day()).leftPad(2, '0') + '.' +
            String.valueOf(today.month()).leftPad(2, '0') + '.' +
            String.valueOf(today.year()) + '.';

        template = template.replace('{{DATE}}', formattedDate);

        // A szerkesztett ajánlati HTML behelyettesítése.
        // Nem escape-eljük, mert meg kell őrizni a HTML-formázást.
        template = template.replace(
            '{{QUOTE_BODY}}',
            normalizeHtml(quoteBody)
        );

        return template;
    }

    /**
     * HTML sablon betöltése Static Resource-ból.
     */
    private static String loadTemplate() {

        if (cachedTemplate != null) {
            return cachedTemplate;
        }

        List<StaticResource> resources = [
            SELECT Body
            FROM StaticResource
            WHERE Name = 'SolarQuotePdfTemplate'
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            throw new PdfTemplateException(
                'Nem található a SolarQuotePdfTemplate Static Resource.'
            );
        }

        cachedTemplate = resources[0].Body.toString();

        return cachedTemplate;
    }

    /**
     * CSS betöltése Static Resource-ból.
     */
    private static String loadStyles() {

        if (cachedStyles != null) {
            return cachedStyles;
        }

        List<StaticResource> resources = [
            SELECT Body
            FROM StaticResource
            WHERE Name = 'SolarQuotePdfStyles'
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            throw new PdfTemplateException(
                'Nem található a SolarQuotePdfStyles Static Resource.'
            );
        }

        cachedStyles = resources[0].Body.toString();

        return cachedStyles;
    }

    /**
     * A szerkesztőből érkező HTML alapvető normalizálása.
     *
     * Megőrzi a formázó tageket, attribútumokat és táblázatokat.
     * Nem alakítja át a HTML-t egyszerű szöveggé.
     */
    private static String normalizeHtml(String html) {

        if (String.isBlank(html)) {
            return '';
        }

        String result = html;

        // A már létező HTML entitásokat megőrizzük,
        // a nyers ampersand karaktereket viszont escape-eljük.
        result = result.replaceAll(
            '&(?!amp;|lt;|gt;|quot;|apos;|#\\d+;|#x[0-9a-fA-F]+;)',
            '&amp;'
        );

        // XHTML-kompatibilis önlezárás a void elemeknél.
        result = result.replaceAll(
            '(?i)<(br|hr)\\s*>',
            '<$1 />'
        );

        result = result.replaceAll(
            '(?i)<(img|col)([^>]*?)(?:\\s*/)?\\s*>',
            '<$1$2 />'
        );

        return result;
    }

    public class PdfTemplateException extends Exception {
    }
}