# Atea upphandling

En lokal macOS-app för att läsa stora svenska upphandlingsdokument, skapa en
spårbar kravlista och söka efter specifika villkor. Dokumenten lämnar inte
datorn.

## Funktioner

- Rekursiv import av hela mappar med PDF-, Excel- (`.xls` och `.xlsx`), TXT- och Markdown-filer
- Flera separata upphandlingsprojekt med projektväxling, namnbyte och säker borttagning
- Strukturerad produktlista med artikelnummer, specifikationer, krav, kalkylblad och rad
- Online-matchning som täcker samtliga produktrader, grupperar identiska behov och skapar kravbaserade sökningar hos Atea, på webben och mot tillverkarkällor
- Tydlig skillnad mellan automatiska sökunderlag och manuellt källverifierade produktkandidater
- Lokal chunkning och BM25-baserad RAG-sökning
- Klickbara sökträffar som öppnar PDF på rätt sida eller markerar rätt kalkylblad och textavsnitt
- Automatisk kravextraktion med dokument- och sidhänvisning
- Filtrering och granskning av obligatoriska krav, utvärderingskrav och avtalskrav
- Källgrundade svar och kravsammanställningar med Apple Intelligence
- Individuell Apple Intelligence-förklaring för varje krav med innebörd, leverantörsåtgärder och kontrollpunkter
- Visuell svarsplan med granskningsgrad, prioriterat arbetsflöde och status per kravtyp
- Sexstegs anbudsguide som tydligt markerar obligatorisk input och återstående arbete
- Kravsvar med status, svarstext, verifierbart bevis och namngiven ansvarig
- Export av komplett svarsplan och kravmatris till riktig Word DOCX och PDF
- Lokal lagring i Application Support

### Projekt och svarsplaner

Välj **Nytt projekt från mapp** för varje upphandling. Dokument, sökindex,
krav, produkter och granskningsstatus hålls separerade per projekt. Under
**Alla projekt** går det att växla, byta namn och ta bort projekt utan att
originalfilerna påverkas.

Varje projektkort har en tydlig röd **Ta bort projekt**-knapp. Borttagningen
kräver bekräftelse och raderar endast projektets sparade analys i appen;
originalmappen och dess dokument ligger kvar på datorn.

Sidan **Svarsplan** visar hur långt granskningen har kommit och ger ett
rekommenderat anbudsflöde. **Exportera DOCX + PDF** skapar:

- lägesbild och prioriterad arbetsordning
- krav- och svarsmatris med källhänvisningar
- befintliga Apple Intelligence-sammanfattningar som svarsstöd
- dokument- och produktkontroll
- checklista för slutlig kvalitetssäkring

### Anbudsguide

**Anbudsguide** leder användaren genom sex steg:

1. upphandlingsreferens, beställare, deadline, portal och omfattning
2. anbudsgivare, kontaktuppgifter och namngivna ansvariga
3. bedömning, svar, bevis och ansvarig för varje identifierat krav
4. erbjudande, produktverifiering, priskontroll och leveranskapacitet
5. leveransplan, informationssäkerhet och hållbarhet
6. bilagor, juridisk granskning, oberoende kvalitetskontroll och export

Saknade uppgifter visas i rött på respektive fält och räknas både per steg och
för hela projektet. Alla svar sparas automatiskt i det aktiva projektet och
följer med till DOCX- och PDF-exporten.

## Krav

- macOS 14 eller senare för lokal sökning och kravextraktion
- macOS 26, Apple Silicon och aktiverad Apple Intelligence för AI-svar
- Swift 6 / Xcode 26 rekommenderas

## Kör

Öppna `Package.swift` i Xcode och kör schemat `ProcurementRAG`, eller använd:

```bash
swift run ProcurementRAG
```

Testerna körs med:

```bash
swift test
```

## Installera en GitHub-release

1. Hämta den senaste DMG-filen från repositoryts **Releases**.
2. Öppna DMG-filen och dra **Atea upphandling** till **Applications**.
3. Första gången: kontroll-klicka på appen i Finder och välj **Öppna**.

Releasepaketen är för närvarande ad hoc-signerade, inte Developer ID-signerade
eller notariserade. macOS visar därför en Gatekeeper-varning. Källkod och
SHA-256-kontrollsummor publiceras tillsammans med varje release.

## Skapa macOS-paket

```bash
chmod +x Scripts/package-macos.sh
Scripts/package-macos.sh 1.0.0
```

Skriptet skapar en optimerad release, en macOS-app med ikon, en DMG med
Applications-genväg, ett ZIP-arkiv och SHA-256-kontrollsummor i `dist/`.

### Atea-logotyp

Appen använder Atea-företagets ordmärke. Atea.se blockerar automatiserad
hämtning av sidresurser, därför används den identiska offentliga SVG-filen från
[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Atea_(company)_logo.svg).
Atea och Atea-logotypen är varumärken som tillhör Atea.
