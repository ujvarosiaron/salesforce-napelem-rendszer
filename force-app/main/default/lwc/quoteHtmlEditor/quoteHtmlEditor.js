import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class QuoteHtmlEditor extends LightningElement {
    // A meta.xml Flow-tulajdonságainak léteznie kell @api mezőként is
    @api content;
    @api markdown;

    _initialContent;
    _editorInitialized = false;
    dirty = false;

    @api
    get initialContent() {
        return this._initialContent;
    }
    set initialContent(value) {
        this._initialContent = value;
        // Ha az érték később érkezik, mint az első render, töltsük be
        if (!this._editorInitialized) {
            const editor = this.template.querySelector('.html-editor');
            if (editor) {
                this.loadContent(editor);
            }
        }
    }

    renderedCallback() {
        if (this._editorInitialized) {
            return;
        }
        const editor = this.template.querySelector('.html-editor');
        if (editor) {
            this.loadContent(editor);
        }
    }

    // 1. lépés: JSON-csomagolás (pl. {"blocks":[...]}) kibontása, ha mégis ilyen érkezne
    unwrapContent(raw) {
        if (!raw) return '';
        let value = String(raw).trim();

        for (let i = 0; i < 3; i++) {
            if (!(value.startsWith('{') || value.startsWith('['))) break;
            try {
                const parsed = JSON.parse(value);

                if (parsed && Array.isArray(parsed.blocks)) {
                    value = parsed.blocks
                        .map((b) => (b && b.data && b.data.text) ? b.data.text : '')
                        .filter((t) => t.trim() !== '')
                        .join('');
                } else if (parsed && parsed.data && typeof parsed.data.text === 'string') {
                    value = parsed.data.text;
                } else {
                    break;
                }
                value = value.trim();
            } catch (e) {
                break; // nem JSON, valódi HTML
            }
        }
        return value;
    }

    // 2. lépés: kódblokk-jelölők és felesleges térközök törlése
    cleanHtml(raw) {
        if (!raw) return '';
        let html = raw;

        // Markdown kódblokk-jelölők eltávolítása
        html = html.replace(/^\s*```(?:html)?\s*/i, '').replace(/\s*```\s*$/i, '');

        // Üres bekezdések és felesleges <br>-ek törlése
        html = html.replace(/<p>\s*(&nbsp;|<br\s*\/?>)?\s*<\/p>/gi, '');
        html = html.replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');

        // Táblázat- és blokk-tagek közé szúrt <br>-ek törlése. Ha a Flow a sortöréseket
        // <br>-ré alakítja, a böngésző ezeket a táblázat ELÉ tolja ki (foster parenting),
        // ez adja az óriási térközt.
        html = html.replace(
            /(<\/?(?:table|thead|tbody|tfoot|tr|td|th|ul|ol|li|h[1-6]|p|hr|div)\b[^>]*>)\s*(?:<br\s*\/?>\s*)+(?=<)/gi,
            '$1'
        );

        // Szóközök/sortörések eltávolítása blokk-szintű tagek után
        html = html.replace(
            /(<\/?(?:table|thead|tbody|tr|ul|ol|li|h[1-6]|p|hr|div)[^>]*>)\s+(?=<)/gi,
            '$1'
        );

        // <br> közvetlenül a táblázat előtt/után
        html = html.replace(/(<br\s*\/?>)+\s*(<table)/gi, '$2');
        html = html.replace(/(<\/table>)\s*(<br\s*\/?>)+/gi, '$1');

        return html.trim();
    }

    loadContent(editor) {
        const html = this.cleanHtml(this.unwrapContent(this._initialContent));

        if (!html) {
            return;
        }

        editor.innerHTML = html;

        // Biztonsági háló: a szerkesztő közvetlen gyerekei között elkóborolt <br>-ek törlése
        Array.from(editor.children)
            .filter((el) => el.tagName === 'BR')
            .forEach((el) => el.remove());

        this.stripWhitespaceNodes(editor);
        this.fixEmptyCells(editor);

        this._editorInitialized = true;
        this.dirty = false;

        // Kezdeti érték kiadása, hogy a flow-ban akkor is legyen output,
        // ha a felhasználó nem szerkeszt semmit
        this.publish();
    }

    // Az elemek közti, sortörést tartalmazó, csak szóközből álló szövegcsomópontok
    // törlése. Ezek (különösen táblázatokban és pre-wrap környezetben) óriási
    // üres tereket okoznak. A szövegen belüli sortöréseket szóközre cseréli.
    stripWhitespaceNodes(root) {
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        const toRemove = [];

        while (walker.nextNode()) {
            const node = walker.currentNode;
            if (/^\s*$/.test(node.nodeValue) && /[\r\n\t]/.test(node.nodeValue)) {
                toRemove.push(node);
            } else if (/[\r\n]/.test(node.nodeValue)) {
                node.nodeValue = node.nodeValue.replace(/\s*[\r\n]+\s*/g, ' ');
            }
        }

        toRemove.forEach((n) => n.parentNode && n.parentNode.removeChild(n));
    }

    // A stílus már inline benne van a HTML-ben, ezt nem írjuk felül.
    // Csak az üres cellák ne essenek össze szerkesztéskor.
    fixEmptyCells(editor) {
        editor.querySelectorAll('th, td').forEach((cell) => {
            if (!cell.innerHTML.trim()) {
                cell.innerHTML = '&nbsp;';
            }
        });
    }

    handleInput() {
        this.dirty = true;
    }

    handleBlur() {
        this.publish();
    }

    publish() {
        const editor = this.template.querySelector('.html-editor');
        if (!editor) {
            return;
        }

        // Mentés előtt a tagek közti sortöréseket is kivesszük
        const finalHtml = editor.innerHTML.replace(/>\s*[\r\n]+\s*</g, '><');

        this.dispatchEvent(new FlowAttributeChangeEvent('content', finalHtml));
        this.dispatchEvent(new FlowAttributeChangeEvent('markdown', finalHtml));

        this.dirty = false;
    }

    @api
    validate() {
        this.publish();
        return { isValid: true };
    }
}