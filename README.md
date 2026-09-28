# Upphandlingsanalys med lokal RAG

En lokal macOS-app för att läsa stora svenska upphandlingsdokument, skapa en
spårbar kravlista och söka efter specifika villkor. Dokumenten lämnar inte
datorn.

## Funktioner

- Rekursiv import av hela mappar med PDF-, Excel- (`.xls` och `.xlsx`), TXT- och Markdown-filer
- Strukturerad produktlista med artikelnummer, specifikationer, krav, kalkylblad och rad
- Online-matchning som täcker samtliga produktrader, grupperar identiska behov och skapar kravbaserade sökningar hos Atea, på webben och mot tillverkarkällor
- Tydlig skillnad mellan automatiska sökunderlag och manuellt källverifierade produktkandidater
- Lokal chunkning och BM25-baserad RAG-sökning
- Klickbara sökträffar som öppnar PDF på rätt sida eller markerar rätt kalkylblad och textavsnitt
- Automatisk kravextraktion med dokument- och sidhänvisning
- Filtrering och granskning av obligatoriska krav, utvärderingskrav och avtalskrav
- Källgrundade svar och kravsammanställningar med Apple Intelligence
- Individuell Apple Intelligence-förklaring för varje krav med innebörd, leverantörsåtgärder och kontrollpunkter
- Lokal lagring i Application Support

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
2. Öppna DMG-filen och dra **Upphandlingsanalys** till **Applications**.
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
