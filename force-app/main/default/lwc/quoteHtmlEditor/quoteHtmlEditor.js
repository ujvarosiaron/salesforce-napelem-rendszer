import { LightningElement, api, track } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

// Alap inline stílusok: az SLDS reset miatt a címsorok sima szövegnek látszanának,
// és a mentett HTML más felületen (rekord, PDF) is helyesen jelenjen meg.
const HEADING_STYLES = {
    H1: { fontSize: '28px', fontWeight: 'bold', margin: '16px 0 8px' },
    H2: { fontSize: '22px', fontWeight: 'bold', margin: '16px 0 8px' },
    H3: { fontSize: '18px', fontWeight: 'bold', margin: '14px 0 6px' },
    H4: { fontSize: '16px', fontWeight: 'bold', margin: '12px 0 6px' }
};

export default class QuoteHtmlEditor extends LightningElement {
    // A meta.xml Flow-tulajdonságainak léteznie kell @api mezőként is
    @api content;
    @api markdown;

    _initialContent;
    _editorInitialized = false;
    _savedRange = null;
    _selectionHandler;

    @track showLink = false;
    linkUrl = '';
    dirty = false;

    @api
    get initialContent() {
        return this._initialContent;
    }
    set initialContent(value) {
        this._initialContent = value;
        if (!this._editorInitialized) {
            const editor = this.editor;
            if (editor) {
                this.loadContent(editor);
            }
        }
    }

    get editor() {
        return this.template.querySelector('.html-editor');
    }

    connectedCallback() {
        // A kijelölést folyamatosan mentjük, mert a legördülő listák és a színválasztó elveszik a fókuszt
        this._selectionHandler = () => this.saveSelection();
        document.addEventListener('selectionchange', this._selectionHandler);
    }

    disconnectedCallback() {
        document.removeEventListener('selectionchange', this._selectionHandler);
    }

    renderedCallback() {
        if (this._editorInitialized) {
            return;
        }
        const editor = this.editor;
        if (editor) {
            this.loadContent(editor);
        }
    }

    // ---------------------------------------------------------------
    // Betöltés és tisztítás
    // ---------------------------------------------------------------

    // JSON-csomagolás (pl. {"blocks":[...]}) kibontása, ha mégis ilyen érkezne
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
                break;
            }
        }
        return value;
    }

    cleanHtml(raw) {
        if (!raw) return '';
        let html = raw;

        // Markdown kódblokk-jelölők eltávolítása
        html = html.replace(/^\s*```(?:html)?\s*/i, '').replace(/\s*```\s*$/i, '');

        // Üres bekezdések és felesleges <br>-ek törlése
        html = html.replace(/<p>\s*(&nbsp;|<br\s*\/?>)?\s*<\/p>/gi, '');
        html = html.replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');

        // Táblázat- és blokk-tagek közé szúrt <br>-ek törlése (a Flow a sortöréseket
        // <br>-ré alakíthatja, a böngésző ezeket a táblázat elé tolja ki)
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

        // Elkóborolt <br>-ek törlése a szerkesztő közvetlen gyerekei közül
        Array.from(editor.children)
            .filter((el) => el.tagName === 'BR')
            .forEach((el) => el.remove());

        this.stripWhitespaceNodes(editor);
        this.fixEmptyCells(editor);
        this.applyDefaultInlineStyles(editor);

        this._editorInitialized = true;
        this.dirty = false;

        // Kezdeti érték kiadása, hogy a flow-ban akkor is legyen output
        this.publish();
    }

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

    fixEmptyCells(editor) {
        editor.querySelectorAll('th, td').forEach((cell) => {
            if (!cell.innerHTML.trim()) {
                cell.innerHTML = '&nbsp;';
            }
        });
    }

    // Csak azt pótolja, ami még nincs inline megadva, a meglévő stílusokat nem írja felül
    applyDefaultInlineStyles(editor) {
        Object.keys(HEADING_STYLES).forEach((tag) => {
            const styles = HEADING_STYLES[tag];
            editor.querySelectorAll(tag.toLowerCase()).forEach((el) => {
                Object.keys(styles).forEach((prop) => {
                    if (!el.style[prop]) {
                        el.style[prop] = styles[prop];
                    }
                });
            });
        });

        editor.querySelectorAll('a[href]').forEach((a) => {
            if (!a.style.color) a.style.color = '#0176d3';
            if (!a.style.textDecoration) a.style.textDecoration = 'underline';
            a.setAttribute('target', '_blank');
            a.setAttribute('rel', 'noopener noreferrer');
        });

        editor.querySelectorAll('ol, ul').forEach((list) => {
            if (!list.style.listStyleType) {
                list.style.listStyleType = list.tagName === 'OL' ? 'decimal' : 'disc';
            }
            if (!list.style.paddingLeft) list.style.paddingLeft = '24px';
            if (!list.style.margin) list.style.margin = '0 0 10px';
        });

        editor.querySelectorAll('p').forEach((p) => {
            if (!p.style.margin && !p.closest('td, th')) {
                p.style.margin = '0 0 10px';
            }
        });
    }

    // ---------------------------------------------------------------
    // Kijelölés kezelése
    // ---------------------------------------------------------------

    saveSelection() {
        const editor = this.editor;
        const sel = window.getSelection();
        if (!editor || !sel || sel.rangeCount === 0) {
            return;
        }
        const range = sel.getRangeAt(0);
        if (editor.contains(range.commonAncestorContainer)) {
            this._savedRange = range.cloneRange();
        }
    }

    restoreSelection() {
        const editor = this.editor;
        if (!editor) {
            return;
        }
        editor.focus();
        if (this._savedRange) {
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(this._savedRange);
        }
    }

    // ---------------------------------------------------------------
    // Eszköztár
    // ---------------------------------------------------------------

    handleToolbarMouseDown(event) {
        const tag = event.target && event.target.tagName;
        // A legördülő listák és a színválasztó normál működését meghagyjuk
        if (tag === 'SELECT' || tag === 'OPTION' || tag === 'INPUT' || tag === 'LABEL') {
            return;
        }
        // A gombok ne vegyék el a fókuszt/kijelölést a szerkesztőtől
        event.preventDefault();
    }

    exec(command, value = null, useCss = false) {
        this.restoreSelection();
        document.execCommand('styleWithCSS', false, useCss);
        document.execCommand(command, false, value);
        this.saveSelection();
        this.publish();
    }

    handleCommand(event) {
        const cmd = event.currentTarget.dataset.cmd;
        if (cmd) {
            this.exec(cmd, null, false);
        }
    }

    handleAlignMenu(event) {
        this.exec(event.detail.value, null, false);
    }

    handleBlockChange(event) {
        const value = event.target.value;
        if (value) {
            this.exec('formatBlock', '<' + value + '>', false);
        }
        event.target.value = '';
    }

    handleFontFamily(event) {
        const value = event.target.value;
        if (value) {
            this.exec('fontName', value, true);
        }
        event.target.value = '';
    }

    handleFontSize(event) {
        const px = event.target.value;
        event.target.value = '';
        if (!px) {
            return;
        }

        this.restoreSelection();
        document.execCommand('styleWithCSS', false, false);
        document.execCommand('fontSize', false, '7');

        // A '7-es' <font> elemeket valódi px méretű span-ra cseréljük
        this.editor.querySelectorAll('font[size="7"]').forEach((font) => {
            const span = document.createElement('span');
            span.style.fontSize = px + 'px';
            while (font.firstChild) {
                span.appendChild(font.firstChild);
            }
            font.parentNode.replaceChild(span, font);
        });

        this.saveSelection();
        this.publish();
    }

    handleColor(event) {
        const value = event.target.value;
        const command = event.target.dataset.type === 'back' ? 'hiliteColor' : 'foreColor';
        this.exec(command, value, true);
    }

    // ---------------------------------------------------------------
    // Hivatkozás
    // ---------------------------------------------------------------

    handleLinkToggle() {
        this.saveSelection();
        this.showLink = !this.showLink;
        if (!this.showLink) {
            this.linkUrl = '';
        }
    }

    handleLinkInput(event) {
        this.linkUrl = event.target.value;
    }

    handleLinkInsert() {
        let url = (this.linkUrl || '').trim();
        if (!url) {
            return;
        }
        if (!/^(https?:\/\/|mailto:|tel:)/i.test(url)) {
            url = 'https://' + url;
        }

        this.exec('createLink', url, false);

        this.showLink = false;
        this.linkUrl = '';
    }

    handleLinkRemove() {
        this.exec('unlink', null, false);
        this.showLink = false;
        this.linkUrl = '';
    }

    // ---------------------------------------------------------------
    // Táblázat műveletek
    // ---------------------------------------------------------------

    getCurrentCell() {
        const range = this._savedRange;
        const editor = this.editor;
        if (!range || !editor) {
            return null;
        }
        const node = range.startContainer;
        const el = node.nodeType === 1 ? node : node.parentElement;
        const cell = el && el.closest ? el.closest('td, th') : null;
        return cell && editor.contains(cell) ? cell : null;
    }

    // Az a sor, ami a legtöbb cellát tartalmazza (törzssor előnyben), ebből másoljuk a stílust
    getReferenceRow(table) {
        const rows = Array.from(table.rows);
        const bodyRows = rows.filter((r) => r.cells.length && r.cells[0].tagName === 'TD');
        const pool = bodyRows.length ? bodyRows : rows;
        return pool.reduce((a, b) => (b.cells.length > a.cells.length ? b : a), pool[0]);
    }

    handleTableMenu(event) {
        const action = event.detail.value;
        const cell = this.getCurrentCell();

        if (!cell) {
            // eslint-disable-next-line no-alert
            window.alert('Előbb kattints egy táblázatcellába.');
            return;
        }

        const row = cell.parentElement;
        const table = cell.closest('table');
        const colIndex = cell.cellIndex;

        switch (action) {
            case 'rowBefore':
            case 'rowAfter':
                this.insertRow(table, row, action === 'rowAfter');
                break;
            case 'colBefore':
            case 'colAfter':
                this.insertColumn(table, colIndex, action === 'colAfter');
                break;
            case 'deleteRow':
                row.remove();
                if (!table.rows.length) table.remove();
                break;
            case 'deleteCol':
                this.deleteColumn(table, colIndex);
                break;
            case 'deleteTable':
                table.remove();
                break;
            default:
                return;
        }

        this._savedRange = null;
        this.publish();
    }

    insertRow(table, row, after) {
        const ref = this.getReferenceRow(table);
        const newRow = document.createElement('tr');
        const refStyle = ref.getAttribute('style');
        if (refStyle) newRow.setAttribute('style', refStyle);

        Array.from(ref.cells).forEach((refCell) => {
            const td = document.createElement('td');
            const style = refCell.getAttribute('style');
            if (style) td.setAttribute('style', style);
            td.colSpan = refCell.colSpan;
            td.innerHTML = '&nbsp;';
            newRow.appendChild(td);
        });

        const inHead = row.parentElement && row.parentElement.tagName === 'THEAD';
        if (inHead) {
            // Fejlécsor alá/fölé új törzssor kerül: a törzs elejére tesszük
            let tbody = table.tBodies[0];
            if (!tbody) {
                tbody = document.createElement('tbody');
                table.appendChild(tbody);
            }
            tbody.insertBefore(newRow, tbody.firstChild);
        } else if (after) {
            row.parentElement.insertBefore(newRow, row.nextSibling);
        } else {
            row.parentElement.insertBefore(newRow, row);
        }
    }

    insertColumn(table, idx, after) {
        const target = after ? idx + 1 : idx;

        Array.from(table.rows).forEach((r) => {
            const spanCell = Array.from(r.cells).find((c) => c.colSpan > 1);
            if (spanCell) {
                // Összevont cellás sor (pl. végösszeg): a cellát szélesítjük
                spanCell.colSpan += 1;
                return;
            }

            const refCell = r.cells[Math.min(idx, r.cells.length - 1)];
            if (!refCell) return;

            const newCell = refCell.cloneNode(false);
            newCell.style.width = '';
            newCell.innerHTML = '&nbsp;';

            const before = r.cells[target] || null;
            r.insertBefore(newCell, before);
        });
    }

    deleteColumn(table, idx) {
        Array.from(table.rows).forEach((r) => {
            const spanCell = Array.from(r.cells).find((c) => c.colSpan > 1);
            if (spanCell) {
                spanCell.colSpan -= 1;
                return;
            }
            if (r.cells[idx]) {
                r.deleteCell(idx);
            }
        });

        // Ha nem maradt cella, a táblázat is törlődik
        if (!Array.from(table.rows).some((r) => r.cells.length)) {
            table.remove();
        }
    }

    // ---------------------------------------------------------------
    // Szerkesztő események és mentés
    // ---------------------------------------------------------------

    handleFocus() {
        try {
            // Enterre <p> készüljön <div> helyett
            document.execCommand('defaultParagraphSeparator', false, 'p');
        } catch (e) {
            // nem kritikus
        }
    }

    handleInput() {
        this.dirty = true;
    }

    handleBlur() {
        this.publish();
    }

    publish() {
        const editor = this.editor;
        if (!editor) {
            return;
        }

        this.applyDefaultInlineStyles(editor);

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