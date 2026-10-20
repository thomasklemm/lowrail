# Exaktes Memo für Datei-Digests

Stand: 2026-10-20. Opt-in mit `lowrail build APP --digest-memo`;
Passname `digest/file_memo`. Unabhängig von `--memo` und
`--preload-plans`; ohne Flag werden keine Digest-Dateien verändert.

## Grenze und Auslieferung

Der Pass ersetzt ausschließlich die Intrinsics
`Digest::MD5.file(path).hexdigest` und `Digest::SHA1.file(path).hexdigest`
in `RailsVite::Manifest#digest`/`#watched_files_digest` beziehungsweise
`ViteRuby::Builder#watched_files_digest`/`#file_digest`, soweit vorhanden.
Gem-Code wird mit Prism zeilentreu verändert und über den bestehenden
Compiler-/ISeq-Loader ausgeliefert. Methodennamen, Parameter, Sichtbarkeit,
die umgebenden Rescues und der übrige Gem-Code bleiben erhalten. Der
Helper erhält Algorithmus und Argument genau einmal, in Originalreihenfolge;
bei ungültigem Guard ruft er `algorithm.file(name).hexdigest` auf.

Es gibt **kein Memo für eine beliebige Inertia-Version-Proc**. Die Proc läuft
weiter bei jedem ursprünglichen Aufruf. Gem-eigene Globs, Sortierung,
Verzeichnisfilter, Zeitfenster und bestehende Dateistat-Caches bleiben
unverändert. Insbesondere macht der Pass den bestehenden mtime/size-Cache
von vite_ruby nicht strenger oder schwächer: Nur sein tatsächlich erreichter
SHA1-Dateiaufruf wird spezialisiert.

`gem/exe/lowrail-digest-build` erweitert `units.json` vor dem normalen
Compiler. Gem-Dateien bekommen eigene Units, Ledger-Einträge, Source-Hashes
und Compiler-Fingerprints. Environment-Guard, `LOWRAIL=0`, `LOWRAIL_UNITS`,
`verify --bisect` und die Bisection-Denylist gelten unverändert. Der eigene
Install-Block folgt dem Memo-Block; Capture-/Observe-Hooks werden nicht
verändert.

## Was ein Cache-Hit beweist

Jeder Aufruf öffnet die Datei erneut mit **`rb`** und liest wie
`Digest::Instance#file` in **16.384-Byte-Blöcken mit wiederverwendetem
Read-Buffer** bis EOF. Erst danach wird der vollständige gelesene Byte-String
mit dem privaten Cache-Eintrag verglichen. Nur vollständige Gleichheit
erlaubt die Wiederverwendung. Ein Ruby-String-Hash dient lediglich als Index;
auch bei einer Kollision entscheidet der vollständige Byte-Vergleich.
Dateiname, Stat-Tupel und ein verkürzter Hash sind **kein** Inhaltsbeweis.

Bei einem Miss wird genau dieser bereits gelesene Stream gehasht, nicht
eine erneut geöffnete Datei. Cache-Schlüssel, gespeicherte Bytes und
Hash-Ergebnis sind private Snapshots; das gespeicherte Ergebnis wird
dupliziert und eingefroren, jeder Hit liefert eine neue veränderbare Kopie
mit der ursprünglichen US-ASCII-Kodierung. Ein Thread-Wechsel zwischen
Lesen und Einfügen kann deshalb keinen späteren Dateiinhalt mit einem alten
Digest verknüpfen.

Pro Unit werden höchstens 32 Einträge bis jeweils 1 MiB gehalten. Größere
Streams wechseln nach Überschreiten der Grenze auf inkrementelles Hashen
derselben geöffneten Datei und werden nicht gecacht. Diese Berechnungen,
kalte Misses und fehlgeschlagene Dateioperationen zählen nicht als Hits.
Hits zählen tatsächliche Digest-Wiederverwendung; Fallbacks zählen den
Originalpfad bei Guard-/Eingabeablehnung.

Es gibt **keinen stat-only Modus**, auch nicht implizit als schnelleres Memo.

## Dateirennen und Fehler

Der Vertrag ist ein **Stream-Vertrag**, kein atomarer Dateisnapshot:

- Umbenennen/Ersetzen oder Entfernen des Pfads während des Lesens ändert
  den schon geöffneten Deskriptor nicht. Der erste Digest gehört dessen
  gelesenem Stream; der nächste Aufruf öffnet den dann aktuellen Pfad.
- Eine In-place-Änderung zwischen zwei Reads kann einen gemischten Stream
  aus altem Präfix und neuem Rest ergeben, genau wie im ursprünglichen
  `Digest#file`. Der Cache speichert nur diesen tatsächlich gelesenen Stream;
  beim nächsten Aufruf werden wieder alle Bytes gelesen und verglichen.
- Ein zusätzlicher Kontroll-Read oder ein Neuöffnen nach dem Vergleich würde
  ein anderes Rennen einführen und findet deshalb nicht statt.
- `ENOENT`, `EACCES`, `EISDIR`, leere Dateien, binäre Inhalte und binär
  kodierte Pfade laufen durch dieselben nativen Open-/Read-Operationen.
  Fehlerklassen und Meldungen bleiben erhalten; der ursprüngliche
  RailsVite-`ENOENT`-Rescue liefert weiter seinen Sentinel.
- Integer-Dateideskriptoren brauchen keinen Pfad. Der Helper ruft deshalb
  nicht zusätzlich `File#path` oder eine zweite Pfadkonvertierung auf.

Wie beim Original kann ein von außen gleichzeitig veränderter Stream von
Lauf zu Lauf andere Bytes liefern. Es wird weder ein Snapshot versprochen
noch nachträglich behauptet, das Ergebnis gehöre dem letzten `stat`.

## Guards und Ablehnungen

Der Build zertifiziert die Ruby-Bodies von `Digest::Class.file` und
`Digest::Instance#file` anhand ihrer Tokens; ihre Implementierungsdatei wird
zusammen mit den geladenen nativen Digest-Bibliotheken per SHA-256 gepinnt.
Zunächst ist nur Digest 3.2.1 zertifiziert. Die übersprungenen Digest-Operationen
(`new`, Initialisierung, `update`, `hexdigest`, Clone/Copy und `finish`),
Open/Read, String-Operationen und die eingebaute Pathname-Konvertierung
bekommen Methoden-Facts; native Digest-Owner müssen den Standard-Ownern
entsprechen. Auch Array- und Algorithmus-Hash-/Equality-Dispatch des
Cache-Schlüssels sind gepinnt. Native Aliasse werden über `original_name`
geprüft: gleicher Owner und `source_location == nil` allein genügen nicht.
Definition-/Modul-Hooks invalidieren die Unit und sie validiert erneut.

Akzeptierte Pfade sind echte Strings, Integer-Deskriptoren und normale
Pathnames mit einfachem String-Inhalt und zertifizierter Konvertierung.
Eigene Pfadobjekte/Subklassen bleiben auf dem Originalpfad; deren
`to_path` darf Effekte haben und wird nicht vorab aufgerufen. Ein abweichender
lexikalischer Digest-Receiver und ein überschattetes `Digest::File` werden
ebenfalls nicht umgangen. Der Originalaufruf behält seine Effekte/Fehler.
Die zertifizierten Digest-Module werden erst nach der ersten erfolgreichen
Validierung erfasst, nicht vor Bundler aktiviert. Ein späterer Wechsel der
Namespace-Bindung geht ebenfalls auf den Originalpfad.
Nicht-Haupt-Ractors verwenden den Originalpfad ohne Zugriff auf nicht
teilbare Memo-/Stats-Zustände; deren Fallbacks werden nicht mitgezählt.

Veränderte Ruby-Digest-Bodies, nicht-native/anders aliasierte Primitiven,
angepasste Pfadkonvertierung, Refinements, mehrzeilige Intrinsics und
denylistete Dateien werden konservativ abgelehnt. Unbekannte Ausdrucksformen
werden nicht ersetzt. Die allgemeinen Guard-Grenzen bleiben bestehen:
Definition-Hooks ohne `super`, reine Visibility-Änderungen, Refinements aus
anderem Code, C-seitiges Metaprogramming und ISeq-/Stack-Inspektion werden
nicht zu einem neuen Sicherheitsversprechen. Methoden müssen wie bei
anderen Call-Site-Guards während eines einzelnen Intrinsics stabil bleiben;
gleichzeitiges Monkeypatching mitten in einem IO-Read ist kein zertifiziertes
Synchronisationsprotokoll.

## Öffentliche Fixture und ausführbare Gates

`fixtures/digest-app` ist eine kleine Rails-App ohne Datenbank/JS-Build mit
rails_vite 0.3.0, inertia_rails 3.22.0 und vite_ruby 3.11.1. Ihre Inertia-Version
ist eine lazy Proc. Keine privaten Anwendungssourcen werden benötigt.

```sh
cargo build --release
cargo test
ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].each { require_relative _1 }'
(cd fixtures/digest-app && bundle install)
target/release/lowrail build fixtures/digest-app --digest-memo
target/release/lowrail verify fixtures/digest-app --bisect -- bin/rails test --seed 1729
```

Die Fixture prüft Binärdaten und Ergebnis-Mutierbarkeit, gleiche Länge mit
wiederhergestellter mtime, fehlende/wiederangelegte/leere/unlesbare Dateien,
Verzeichnisfehler, Integer-Deskriptoren und Pfadkodierung. TracePoint-Proben
ersetzen/überschreiben/entfernen eine Datei exakt nach dem ersten Read;
eine andere Probe entfernt einen Treffer nach Glob-Expansion. Zeitreise
prüft Globs samt Reihenfolge und bestehendem Zeitfenster. Die Inertia-Seite
prüft neue Versionen und den 409-Location-Response für veraltete Clients.
EACCES wird nur geprüft, wenn der laufende Nutzer tatsächlich keinen
Lesezugriff hat; root kann Modus 0000 lesen.

Ergebnis: **7/7 identisch, 71 Assertions je Modus, 65 Hits** (52 MD5,
13 SHA1), **0 Fallbacks**, keine Skips. Der Gem-Test prüft außerdem das
Opt-in, absichtliche Clone-/Native-Alias-Overrides, eigene Pfadkonvertierung
und lexikalisches Digest-Shadowing sowie einen Namespace-Wechsel. Ein eigener
Algorithmus-`hash`, den der Originalaufruf nicht verwendet, darf ebenfalls nicht
ausgeführt werden.
Ohne dessen Methoden-Fact scheitert dieselbe öffentliche Probe mit einer
zusätzlichen Exception; mit vollständigem Zertifikat liefert sie den
Original-Digest. Dort sind die sechs gezählten Fallbacks gewollte
Negativkontrollen; nach Wiederherstellung muss das Memo wieder treffen.
Eine weitere Probe prüft den nativen Originalpfad in einem zweiten Ractor.
Eine lexikalisch verfeinerte Methode wird am `using`-AST abgelehnt, auch wenn
der Aufruf nach einem Semikolon steht; ihre abweichende Rückgabe bleibt erhalten.

Aggregate Messungen der privaten Anwendung folgen in
[M0 ARGOS](../m0/argos.md); nur aggregierte Zahlen, keine Anwendungssourcen,
Klassen-, Datei- oder Testnamen.
