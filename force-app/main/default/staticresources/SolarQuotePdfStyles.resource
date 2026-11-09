@page {
    size: A4 portrait;
    margin: 20mm 15mm 20mm 15mm;

    @top-right {
        content: "NAPELEMES BERUHÁZÁSI AJÁNLAT";
        font-family: 'Arial Unicode MS', sans-serif;
        font-size: 8pt;
        font-weight: bold;
        color: #7f8c8d;
    }

    @bottom-right {
        content: "Oldal " counter(page) " / " counter(pages);
        font-family: 'Arial Unicode MS', sans-serif;
        font-size: 8pt;
        color: #95a5a6;
    }
}

body {
    font-family: 'Arial Unicode MS', sans-serif;
    font-size: 10pt;
    line-height: 1.5;
    color: #2c3e50;
}

.company-header {
    width: 100%;
    border-bottom: 2px solid #2c3e50;
    padding-bottom: 12px;
    margin-bottom: 25px;
}

.company-name {
    font-size: 20pt;
    font-weight: bold;
    color: #1a252f;
    letter-spacing: 0.5px;
}

.document-title {
    font-size: 11pt;
    font-weight: bold;
    color: #00875a;
    text-transform: uppercase;
    margin-top: 4px;
}

.section {
    margin-top: 15px;
    margin-bottom: 15px;
}

.body-text {
    width: 100%;
    text-align: justify;
    word-wrap: break-word;
}

.body-text h1,
.body-text h2,
.body-text h3 {
    color: #1b365d !important;
    font-family: 'Arial Unicode MS', sans-serif !important;
    font-weight: bold !important;
    margin-top: 18px !important;
    margin-bottom: 8px !important;
    page-break-after: avoid !important;
}

.body-text table {
    width: 100% !important;
    max-width: 100% !important;
    border-collapse: collapse !important;
    margin: 14px 0 !important;
    table-layout: fixed !important;
}

.body-text tr {
    page-break-inside: avoid !important;
}

.body-text th,
.body-text td {
    border: 1px solid #dcdde1 !important;
    padding: 8px 10px !important;
    font-size: 9.5pt !important;
    word-wrap: break-word !important;
    overflow-wrap: break-word !important;
}

.body-text th {
    background-color: #2c3e50 !important;
    color: #ffffff !important;
    font-weight: bold !important;
    text-align: left !important;
    text-transform: uppercase !important;
    font-size: 8.5pt !important;
}

.body-text td {
    background-color: #ffffff !important;
}

.body-text tr:nth-child(even) td {
    background-color: #f8f9fa !important;
}

.body-text p {
    margin-top: 0;
    margin-bottom: 8px;
}

.body-text ul,
.body-text ol {
    margin-top: 0;
    margin-bottom: 8px;
    padding-left: 18px;
}