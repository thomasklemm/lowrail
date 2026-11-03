# Offene Upstream-PRs: wo wir antworten müssen, und was jeder PR tut

Stand: 2026-11-03, 22:00 UTC. Gelesen mit `gh` (PR-Texte, Diffs, Kommentare, Reviews, CI-Status); nichts wurde
gepostet oder geändert. Der Ledger ist [contributions.md](contributions.md).

Die Beispiele stammen aus den PR-Texten und Tests. Ausgeführt wurden sie auf Ruby 4.0.7: die Rails-Beispiele
gegen Rails main und den jeweiligen PR-Branch (alle zeigen den beschriebenen Unterschied), und bei den
ruby/ruby-Beispielen die Werte für den Interpreter und für YJIT, soweit 4.0.7 sie schon zeigt. Die Werte für
master, ZJIT und die ruby/ruby-PR-Branches stammen aus den PRs; dafür gibt es hier keinen Build.

Teil 1 ist die Antwortliste für morgen früh. Teil 2 erklärt jeden offenen PR auf ruby/ruby (19, davon 2 Drafts) und
rails/rails (10).

## Begriffe

* **Interpreter**: Ruby ohne JIT; führt den Bytecode Befehl für Befehl aus.
* **JIT**: übersetzt häufig laufende Methoden zur Laufzeit in Maschinencode. **YJIT** ist der bisherige JIT
  (laut Maintainern nur noch Fehlerbehebungen), **ZJIT** der neue, an dem die Performance-Arbeit passiert.
* **Allokation**: ein neu angelegtes Ruby-Objekt (String, Array, Hash). Weniger Allokationen heißt weniger Arbeit
  für die Speicherbereinigung (GC). Allokationszahlen schwanken bei gleichem Code nicht.
* **Instruktionen**: von Callgrind (Valgrind) gezählte Maschinenbefehle. Gut reproduzierbar, aber keine Zeit.
* **A/A**: derselbe Code zweimal gemessen. Die Differenz ist das Rauschen; ein Effekt zählt nur, wenn er
  deutlich größer ist.
* **ruby-bench**: die offizielle Benchmark-Sammlung von Ruby. railsbench, lobsters und shipit sind dort echte
  Rails-Anwendungen.
* **Side-Exit**: kompilierter Code springt zurück in den Interpreter, weil eine Annahme nicht stimmt.
  **Fallback** oder **dynamischer Send**: der JIT ruft eine Methode über den langsamen, allgemeinen Weg auf.
* **Profil**: was der JIT vor dem Kompilieren an einer Aufrufstelle beobachtet hat, z. B. welche Klassen ankamen.
* **ISEQ**: der Bytecode einer Methode oder eines Blocks.
* **Refinement**: eine lokal per `using` aktivierte Änderung an einer Klasse; gilt nur in der Datei, die `using` sagt.
* **`opt_new`**: der Bytecode-Befehl für `Foo.new`, der Objekt anlegen und `initialize` aufrufen ohne den
  Umweg über `Class#new` erledigt.

## Teil 1: Antwortliste

Geprüft: alle offenen PRs und Issues von thomasklemm auf ruby/ruby, rails/rails, Shopify/ruby, ruby/rubygems und den
Gems (i18n, propshaft, rack-mini-profiler, inertia-rails, importmap-rails, rubocop-performance, rubocop-rails,
tapioca, tzinfo, bigdecimal, lago-expression, rails_vite, once-campfire), dazu die fremden Threads, in denen wir
kommentiert haben (Shopify/ruby#746, #995, #1058, #1064, #1065, #1091, ruby/ruby#17251, #18326, #18960, #19447,
#19583, Shopify/rubydex#997). Argos, Roundhouse und private Repos sind nicht dabei.

### Antwort nötig

**1. [basecamp/once-campfire#350](https://github.com/basecamp/once-campfire/pull/350#issuecomment-6437614380)**,
namespaceMarcello, 2026-10-27, seit einer Woche offen.

> "Most of what still separates this PR from v1.5.6 on a room page is deriving the fragment keys, and a change on
> top of `1d019ed` removes most of it: two commits on `namespaceMarcello:raw-fragment-keys`, one helper and its
> tests, if you want to take them."

Was er will: dass wir seine zwei Commits übernehmen. Sie bilden den Fragment-Cache-Schlüssel aus den gespeicherten
Rohwerten (`attributes_before_type_cast` und ein SHA-256 des gespeicherten Bodys), statt den Body bei jedem Seitenaufruf
mit Nokogiri neu zu serialisieren. Gemessen hat er Raumseite p50 16,3 → 12,2 ms, Objekte pro Seite 37.000 → 26.600.
Nebenbei hat er gezeigt, dass ein als ungültiger Text gespeicherter Body mit unserem Schlüssel einen 500er
auslöst und dass fünf Mutanten unseres Schlüssels unsere Tests bestehen. Das ist ein echter Befund gegen unseren PR.

Entwurf (Thomas entscheidet, ob wir übernehmen; Übernehmen heißt Push auf den PR-Branch):

> Thanks for digging into this, and sorry for the slow reply. Reading the stored values instead of re-serializing
> the body makes sense to me, and the invalid-text 500 and the mutants your tests catch are real gaps in my key.
> I'll take both commits onto this branch with you as the author, rerun the suite, and update the description with
> your numbers.

**2. [ruby/ruby#19664](https://github.com/ruby/ruby/pull/19664#pullrequestreview-5752852916)**, XrXr, Review
2026-11-03 13:18Z, seitdem nichts von uns.

> "To give reasonable expectations: YJIT is mainly in maintenance mode for bug fixes. For perf improvements we focus
> on ZJIT. This PR touches a high risk part of YJIT so we're unlikely to take it for the next release, as the onus
> of verification is high."

Was er will: Erwartungen setzen; keine Frage. Thomas hat entschieden, die YJIT-PRs offen zu lassen. Eine kurze
Bestätigung ist höflich, aber kein Muss. Gilt sinngemäß auch für #19665 und #19666.

> Thanks for setting expectations. That makes sense; I'll leave it open in case it's useful later, and I'm fine
> with it being closed whenever you prefer.

### Warten auf Antwort (wir haben zuletzt geschrieben)

* **[ruby/ruby#19663](https://github.com/ruby/ruby/pull/19663#issuecomment-6616006957)**: wir haben byroot um
  21:36Z gefragt, ob er den direkten C-Aufruf `rb_hash_s_new` will (dann greift ein Refinement von
  `Hash#initialize` an der Aufrufstelle nicht) oder das Senden von `#initialize` aus dem Aufrufer wie in diesem PR.
  **Bis 22:00 UTC keine Antwort.** Siehe die Erklärung zu #19663 unten.
* **[rails/rails#59577](https://github.com/rails/rails/pull/59577#issuecomment-6609726728)**: fatkodima fragte
  "How do you decide which code needs optimizations … questionable benefits." Beantwortet 16:36Z, PR auf
  `column_references` verkleinert. Keine Reaktion seitdem. Keine weitere Antwort nötig.
* **[ruby/ruby#19678](https://github.com/ruby/ruby/pull/19678)**: alle vier Inline-Kommentare von tekknolagi
  (`r#"`, `fix_to_s` direkt, "why a frame", HIR-Name) mit Commit `3656855d29` erledigt und beantwortet. Wartet
  auf erneutes Review.
* **[ruby/ruby#19661](https://github.com/ruby/ruby/pull/19661)**: tekknolagis "don't mix YJIT and ZJIT" und
  `reg_cfp` erledigt. Wartet.
* **[Shopify/ruby#1058](https://github.com/Shopify/ruby/issues/1058#issuecomment-6614189610)**: auf
  tekknolagis Kritik an der schwer lesbaren Antwort hat Thomas um 20:04Z geantwortet und den Versuch
  zurückgezogen. Nichts offen.

### Keine Antwort nötig

* **[Shopify/ruby#1100](https://github.com/Shopify/ruby/issues/1100#issuecomment-6611201953)**, k0kubun: "It's
  free to take." Darauf folgte ruby/ruby#19682 ("For Shopify/ruby#1100"), das im Issue verlinkt erscheint.
* **[Shopify/ruby#1064](https://github.com/Shopify/ruby/issues/1064#issuecomment-6607679383)**, tekknolagi: "Go
  for it." Erledigt durch ruby/ruby#19680 ("Fixes Shopify/ruby#1064").
* **[Shopify/ruby#1065](https://github.com/Shopify/ruby/issues/1065#issuecomment-6607652909)**, tekknolagi: "go
  for it. Please also try and avoid allocating an interstitial Vec for every CCall." ruby/ruby#19681 sagt im Text
  ausdrücklich "there is no interstitial Vec per CCall".
* **[Shopify/ruby#1091](https://github.com/Shopify/ruby/issues/1091#issuecomment-6607744447)**, tekknolagi:
  "Sure, that is fine." Erledigt durch ruby/ruby#19678 ("Fixes Shopify/ruby#1091").
* **[basecamp/once-campfire#374](https://github.com/basecamp/once-campfire/pull/374#issuecomment-6310596151)**,
  rubys, 2026-10-21: "This composes with #370 rather than competing with it." Eigene Messung, keine Frage.
* **Bot-Kommentare** (chatgpt-codex-connector) auf once-campfire #347, #350, #352, #374, #417 und
  lago-expression#91: Zusammenfassungen "review failed" bzw. "usage limits". Keine Antwort an einen Bot. Inhaltlich
  offen bleiben aber die Codex-Befunde auf
  [#347](https://github.com/basecamp/once-campfire/pull/347) vom 2026-10-09 nach unserem letzten Commit: P1
  "Preserve deferred deletions across database restores" (`hooks/post-restore` löscht beim Restore auch die
  Solid-Queue-Jobs, die gebannte Inhalte oder gelöschte Räume aufräumen), P2 Entwicklungs-Cable über mehrere
  Puma-Worker, P2 getrennte Bundles für die Benchmark-Seiten, P2 `performance`-Umgebung in `config/queue.yml`.
  Nicht beantwortet und, soweit sichtbar, nicht behoben.
* Ohne neue Beiträge anderer: ruby/rubygems#10017, Shopify/ruby#1095 (dazu der fremde PR Shopify/ruby#1097, keine
  Maintainer-Reaktion), Shopify/ruby#1101, alle i18n-, propshaft-, rack-mini-profiler-, inertia-rails-,
  importmap-, rubocop-, tapioca-, tzinfo-, bigdecimal- und rails_vite-PRs, alle übrigen rails/rails- und
  ruby/ruby-PRs.

### Was sonst morgen auffallen kann

* **Rote CI auf drei ZJIT-PRs.** #19678, #19680 und #19681 scheitern im Job `make (zjit-check, …)` auf macOS am
  selben Test, `codegen::tests::test_send_proc_block_arg_to_block_param_callee` ("Program side-exited"). Der Test
  kommt aus unserem gemergten #19484. Master ist im selben Workflow grün (letzte acht Läufe), #19682 und #19685
  auch. Ursache nicht untersucht; ein Reviewer fragt wahrscheinlich danach.
* Andere rote Jobs (#19648, #19620, #19670, #19664–#19666, #19659, #19558, #19492) sind `SHSTK`, `mmtk`,
  bundled-gems, s390x, Windows oder i686. Für #19648 haben wir am 2026-11-02 gezeigt, dass sie auch auf master
  scheitern; für die übrigen ist das nicht geprüft.
* **Shopify/ruby#1101** sagt noch "ruby/ruby#19662 fixes it for ZJIT"; #19662 ist seit heute geschlossen.
* **#19487 und #19492** sind seit 2026-10-22 von k0kubun approved. Ab 2026-11-05 (14 Tage) erlaubt DECISIONS eine
  kurze neutrale Notiz, einmal pro PR.

## Teil 2: Erklärungen pro PR

### Gemeinsamer Kopf für die Rails-Beispiele

Die Rails-Beispiele unten kommen jeweils unter diesen Kopf. Für den Vergleich einmal mit `branch: "main"` und
einmal mit `github: "thomasklemm/rails", branch: "<PR-Branch>"` laufen lassen.

```ruby
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "rails", github: "rails/rails", branch: "main"
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.time_zone_aware_attributes = true # wie in einer Rails-App
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author; t.string :title; t.integer :status, default: 0; t.timestamps }
  create_table(:comments) { |t| t.references :post; t.string :body }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  enum :status, { draft: 0, live: 1 }
end
class Comment < ActiveRecord::Base
  belongs_to :post
  has_one :post_author, through: :post, source: :author
end
author = Author.create!(name: "a")
post = Post.create!(author: author, title: "t")
3.times { post.comments.create!(body: "c") }

def allocs
  yield # einmal aufwärmen
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
end
allocs { } # die erste Messung im Prozess zählt ein Objekt zu viel
```

Für die ruby/ruby-Beispiele braucht man einen Ruby-Build von master bzw. vom PR-Branch
(`thomasklemm/ruby`, Branch wie im PR). Allokationen zählt dort dieselbe Hilfsmethode:

```ruby
def allocs
  2.times { yield } # aufwärmen; mit --yjit-call-threshold=1 / --zjit-call-threshold=1 ist dann kompiliert
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
end
allocs { } # die erste Messung im Prozess zählt ein Objekt zu viel
```

## ruby/ruby: VM (Interpreter)

### ruby/ruby#19670: eine Hash-Allokation für `m(a: v, **h)` (Regression in 4.1)

[PR](https://github.com/ruby/ruby/pull/19670) · offen · Kopf `eb01818c3d`

**Worum es geht.** Auf Ruby 4.0 legt `m(a: v, **h)` einen Hash an, auf master zwei. Seit #18344 baut Prism die
expliziten Schlüssel (`a: v`) erst in einen frischen Hash und kopiert diesen dann beim Zusammenführen mit `**h`
noch einmal. Der PR fügt eine interne Methode `core#hash_merge_fit_kwd` hinzu: Sie führt `**h` direkt in den
frischen Hash ein, wenn das Ergebnis in dessen kleine eingebettete Tabelle passt (bis 8 Einträge), und kopiert
sonst wie bisher. Das ist sicher, weil der frische Hash gerade erst von genau dieser Befehlsfolge angelegt wurde und
noch niemand sonst ihn sehen kann; Inhalt und Reihenfolge der Schlüssel sind dieselben.

```ruby
def m(**kw) = nil
h = { b: 2 }
v = 1
p allocs { m(a: v, **h) } # Ruby 4.0: 1, master: 2, mit dem PR: 1
```

**Die harte Frage.** "Warum nicht immer in den frischen Hash mergen?" Antwort: Über 8 Einträge müsste der Hash von
der eingebetteten Tabelle auf eine große Tabelle umziehen; dann ist die Kopie in einen passend großen Hash nicht
teurer und das alte Verhalten bleibt. Zweite mögliche Frage: Der PR ändert auch `super` ohne Klammern in Methoden
mit benannten Keywords; dort baut jetzt `newhash` die Keywords direkt in einen Hash, statt einen leeren Hash
anzulegen und hineinzukopieren.

**Gemessen.** Hash-Allokationen über 97 Request- und Job-Workloads in neun Rails-Apps auf Rails main, Interpreter:
Ruby 4.0.7 78.103, master 81.992, mit dem PR 77.840. Das sind exakte Zählungen, kein Rauschen; keine Zeitmessung.

### ruby/ruby#19661: `new` auf Hash-Unterklassen wieder auf dem schnellen Weg

[PR](https://github.com/ruby/ruby/pull/19661) · offen · Kopf `ab7dd5fd3c` · baut auf #19660 auf (gemergt
2026-11-03 von byroot)

**Worum es geht.** Seit #19537 hat `Hash` eine eigene Klassenmethode `new`. Damit erbt jede Unterklasse
(`HashWithIndifferentAccess`, `ActiveSupport::OrderedOptions`) diese Methode, und `opt_new` erkennt den Aufruf nicht
mehr als gewöhnliches `Class#new`: Es macht einen echten Aufruf von `Hash.new`, das für Unterklassen dann doch nur
`Class#new` ausführt. Der PR lässt den Interpreter `Hash.new` auf einer Unterklasse wie `Class#new` behandeln.
Sicher, weil `Hash.new` für Unterklassen genau das tut; für `Hash` selbst bleibt der eigene Weg (mit `capacity:`).
Nur der Interpreter ändert sich; die JITs behalten das Verhalten von master.

```ruby
class H < Hash
  def initialize = (@bt = caller(1, 2))
  attr_reader :bt
end
p H.new.bt
# vor #19537 und mit dem PR: ["-:5:in '<main>'"]
# master:                    ["-:5:in 'Hash.new'", "-:5:in '<main>'"]
```

**Die harte Frage.** "Warum nur im Interpreter, und warum ist `val != rb_cHash` nötig?" Antwort: tekknolagi will
VM und JIT nicht im selben PR; die JITs folgen getrennt. Für `Hash` selbst muss `rb_hash_s_new` laufen, weil es
`capacity:` auswertet; nur für Unterklassen ist es dasselbe wie `Class#new`.

**Gemessen.** `HI.new` (Unterklasse mit eigenem `initialize`) im Interpreter, Nanosekunden pro Aufruf, beste von 7
Wiederholungen, zwei Läufe: vor #19537 109,8 / 107,9, master 143,1 / 148,2, mit dem PR 104,0 / 113,9. Das ist Zeit,
keine Instruktionen; der Unterschied von etwa 35 ns ist deutlich größer als die Streuung zwischen den Läufen (bis
10 ns). Pro ruby-bench-Iteration wird `new` auf einer Hash-Unterklasse 17.957-mal (railsbench) aufgerufen; ein
Effekt auf ruby-bench ist nicht gemessen.

## ruby/ruby: ZJIT

### ruby/ruby#19483: `protected`-Aufrufe direkt kompilieren

[PR](https://github.com/ruby/ruby/pull/19483) · offen · Kopf `70a47d2cad`

**Worum es geht.** Eine `protected`-Methode darf nur aufgerufen werden, wenn `self` beim Aufrufer eine Instanz der
definierenden Klasse ist. ZJIT prüft das nicht selbst und lässt deshalb jeden Aufruf wie `other.cents` auf dem
langsamen allgemeinen Weg, auch wenn Klasse und Zielmethode bekannt sind. Der PR ruft die Methode direkt auf, hinter
einem Typtest (`IsA`) auf das `self` des Aufrufers; schlägt der fehl, springt der Code zurück in den Interpreter, der
den richtigen `NoMethodError` wirft. Refinements, per Alias definierte protected-Methoden und Aufrufe aus
eingebetteten (inlined) Methoden bleiben beim alten Weg.

```ruby
class Money
  def initialize(cents) = @cents = cents
  def ==(other) = cents == other.cents # other.cents ist ein protected-Aufruf
  protected def cents = @cents
end
a, b = Money.new(1), Money.new(1)
i = 0
while i < 1_000_000
  a == b
  i += 1
end
# ruby --zjit --zjit-stats: send_fallback_send_not_optimized_need_permission
# ist auf master etwa 1.000.000, mit dem PR 0
```

**Die harte Frage.** "hexapdf ist in jedem Lauf 3 % langsamer. Warum?" Antwort: Das wissen wir nicht. hexapdf macht
laut Zählern keine solchen Aufrufe, seine Zähler ändern sich nicht. Auf den Rails-Benchmarks sinken die
Instruktionen. Das steht so auch im PR.

**Gemessen.** Fallbacks pro Iteration: railsbench 54.836 → 0, shipit 30.469 → 94, lobsters 15.959 → 107.
Callgrind-Instruktionen pro Iteration: railsbench −0,62 % (A/A 0,10 %), shipit −0,31 % (A/A 0,03 %), lobsters
−0,06 % (A/A 0,20 %, also im Rauschen) ([Messung](zjit-open-prs-on-rails.md)). Laufzeit auf ruby-bench: Mittel
über 16 Benchmarks 0,996 (PR/Basis, Spanne 0,990–1,001), also kein messbarer Effekt.

### ruby/ruby#19558 (Draft): Fehlschläge bei mehreren Shapes neu profilieren

[PR](https://github.com/ruby/ruby/pull/19558) · Draft seit 2026-11-03 · Kopf `ad6449b8ec`

**Worum es geht.** Objekte derselben Klasse können verschiedene "Shapes" haben, je nachdem, welche
Instanzvariablen in welcher Reihenfolge gesetzt wurden. Sieht das Profil einer Aufrufstelle eine Klasse mit
mehreren Shapes, behandelt ZJIT sie als polymorph und baut einen Zweig plus einen allgemeinen Fallback. Kommt später
eine andere Klasse, nimmt sie bei jedem Aufruf den Fallback, und ZJIT lernt nie dazu. Der PR macht aus diesem
Fallback einen Side-Exit, der neu kompiliert, wie bei einer monomorphen Stelle. Aufrufstellen, die wirklich mehrere
Klassen sehen, Splat-Aufrufe und finale Versionen bleiben wie bisher.

```ruby
class A
  def initialize(x) = (x ? @a = 1 : @b = 1) # zwei Shapes derselben Klasse
  def v = 1
end
class B; def v = 2; end
def call(o) = o.v
shapes = [A.new(true), A.new(false)]
1_000.times { shapes.each { |o| call(o) } } # Profil: eine Klasse, zwei Shapes
b = B.new
100_000.times { call(b) }                   # master: jedes Mal Fallback; PR: lernt B
```

**Die harte Frage.** dak2: "Warum nicht so ein Profil einfach als monomorph einstufen?" Beantwortet am 2026-10-28:
Dann wird auf die Shape des ersten Eintrags spezialisiert, und beim Schreiben von Attributen springt jede andere
Shape bei jedem Aufruf heraus. Die zweite Frage ist die eigentliche: "Lohnt sich das, wenn die Zeit sich nicht
ändert?" Darum ist es ein Draft.

**Gemessen.** Über 16 Benchmarks, Prozesssummen: polymorphe Fallbacks 20.763.714 → 16.787.818, dynamische Sends
87.940.035 → 84.116.799 (erubi-rails 12.222.068 → 8.921.915); megamorphe Fallbacks steigen 8.175.838 → 8.317.469.
Zeit: drei verschachtelte Läufe PR/Basis 0,986 / 1,006 / 0,997 gegen A/A 1,006 / 0,997 / 0,996, also kein
messbarer Effekt.

### ruby/ruby#19655: leeres anonymes `*` ohne neues Array

[PR](https://github.com/ruby/ruby/pull/19655) · offen · Kopf `852298882d` · nur noch ZJIT (der YJIT-Teil wurde
entfernt)

**Worum es geht.** Eine Methode mit anonymem Rest-Parameter (`def initialize(*) = super`) bekommt bei einem Aufruf
ohne zusätzliche Argumente ein leeres Array. Der Interpreter gibt dafür seit 43683e1e9d ein gemeinsames, gefrorenes
leeres Array weiter; ZJIT legt jedes Mal ein neues an. Der PR macht ZJIT wie den Interpreter, so wie #9972 es für
`**` getan hat. Sicher, weil der Parameter keinen Namen hat: Man kann ihn nur als `*` weiterreichen, nicht ändern.

```ruby
def f(*) = nil
p allocs { f } # Interpreter: 0, ZJIT master: 1, ZJIT mit dem PR: 0
```

**Die harte Frage.** "In einem Fall allokiert ZJIT jetzt weniger als der Interpreter (`def f(a = nil, *)` mit
`f(1)`). Ist das sichtbar?" Antwort: Nein. Der Rest-Parameter ist leer und namenlos; niemand kann das Array sehen
oder ändern.

**Gemessen.** ruby-bench unter ZJIT, Objekte pro Iteration: shipit −1.919 (0,17 %), lobsters −1.057 (0,16 %),
railsbench −2.084 (0,12 %). Allokationen, keine Zeit.

### ruby/ruby#19659: Blöcke mit überzähligen Argumenten direkt aufrufen

[PR](https://github.com/ruby/ruby/pull/19659) · offen · Kopf `bfb53d473e` · löst Shopify/ruby#1094 (Issue von
tekknolagi)

**Worum es geht.** `n.times { }` übergibt dem Block ein Argument, das der Block nicht deklariert. Ein normaler
Block (kein Lambda) wirft überzählige Argumente einfach weg. ZJIT rief einen Block bisher nur direkt auf, wenn die
Anzahl genau passte; sonst ging es über den allgemeinen `invokeblock`-Weg. Der PR ruft auch dann direkt auf und lässt
die überzähligen Argumente fallen, wie Interpreter und YJIT. Die Argumente werden weiterhin ausgewertet; zwei Fälle
bleiben beim alten Weg: ein einzelnes Argument an `|a, b|` (das könnte automatisch entpackt werden) und zu wenige
Argumente (werden mit `nil` aufgefüllt).

```ruby
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
200_000.times { }
p (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / 200_000 * 1e9
# ruby --zjit, Release-Build: master etwa 25 ns pro Iteration, mit dem PR etwa 4,6 ns
```

**Die harte Frage.** "Warum ändert der PR zwei bestehende Tests?" Antwort: In ihnen ist `yield` in `Kernel#then`
jetzt ein direkter Aufruf, der auf die Block-ISEQ prüft; weil jeder Aufruf einen neuen Literalblock übergab, sprang
der Test heraus. Die Tests rufen jetzt über eine Hilfsmethode, damit die Block-ISEQ gleich bleibt.

**Gemessen.** `200_000.times { }` 25,2 → 4,6 ns pro Iteration (Kontrolle `{ |i| }` 4,6 vorher und nachher).
`--zjit-stats` über 16 Benchmarks: `invokeblock_not_specialized` 29,43 M → 29,13 M, direkte Blockaufrufe
39,60 M → 40,07 M. Laufzeit auf ruby-bench innerhalb der Streuung zweier identischer Builds, also kein messbarer
Effekt.

### ruby/ruby#19678: Integer und Module ohne `to_s`-Aufruf interpolieren

[PR](https://github.com/ruby/ruby/pull/19678) · offen · Kopf `b6ed2f484e` · löst Shopify/ruby#1091

**Worum es geht.** Bei `"n#{i}"` oder `"#{klass} Update"` ruft ZJIT `to_s` auf, und das legt einen neuen String an.
Der Interpreter nimmt für 0 bis 9 einen gemeinsamen gefrorenen String und für ein Modul dessen gespeicherten Namen,
legt also einen String weniger an. Der PR ruft an einer Stelle, die nur eine Klasse gesehen hat und deren `to_s` noch
das Original ist, direkt `rb_fix_to_s` oder `rb_mod_name` auf. Abgesichert ist das wie ein normaler C-Aufruf:
Wird `to_s` umdefiniert oder per Refinement geändert, wird wieder gesendet. Ein anonymes Modul springt heraus.

```ruby
def label(i) = "n#{i}"
def update_name(klass) = "#{klass} Update"
p allocs { label(5) }            # Interpreter: 1, ZJIT master: 2, mit dem PR: 1
p allocs { update_name(String) } # Interpreter: 1, ZJIT master: 2, mit dem PR: 1
```

**Die harte Frage.** "Warum nicht einfach als Annotation in `cruby_methods` wie #19587?" Antwort: Ein normaler
Aufruf `5.to_s` muss weiter einen neuen, veränderbaren String liefern; nur bei der Interpolation darf es der
gemeinsame sein. tekknolagis Review-Punkte (direkter `rb_fix_to_s` ohne Frame, klarer HIR-Name) sind umgesetzt.
CI: siehe rote macOS-Jobs oben.

**Gemessen.** ruby-bench unter ZJIT pro Iteration: `to_s`-Aufrufe bei Interpolation lobsters 4.270 → 0, shipit
3.795 → 0; Objekte über dem Interpreter lobsters 1.576 → 931, shipit 3.835 → 1.361 (exakte Zählungen).
Instruktionen (aus dem Issue): lobsters im Rauschen, shipit −0,21 %, alles in der GC.

### ruby/ruby#19680: einmal pro Methode merken, ob sie den Block-Slot schreibt

[PR](https://github.com/ruby/ruby/pull/19680) · offen · Kopf `8cedf94b75` · löst Shopify/ruby#1064

**Worum es geht.** Beim Kompilieren fragt ZJIT für jeden JIT-Frame (einmal pro C-Aufruf mit Frame und pro
Side-Exit), ob die Methode Befehle enthält, die den Block-Slot des Frames schreiben, und durchsucht dafür jedes Mal
den ganzen Bytecode. In einer großen Methode ist das quadratisch. Der PR durchsucht jede ISEQ einmal und speichert
die Antwort. Sicher, weil Profiling und Tracing Befehle nur in Varianten desselben Befehls umschreiben, die die Suche
ohnehin auf den Grundbefehl zurückführt; der erzeugte Code ist unverändert (LIR-Dumps identisch).

```ruby
src = "def big(o)\n  s = 0\n" + ("  s ^= o.hash\n" * 4000) + "  s\nend"
eval src
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
big(Object.new) # mit --zjit --zjit-call-threshold=1 wird big jetzt kompiliert
p Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
# master etwa 3,5 s, mit dem PR etwa 2,3 s (Kompilierzeit)
```

**Die harte Frage.** "Kann die gespeicherte Antwort veralten?" Antwort: Nein, siehe oben; eine Prüf-Build hat
gecachte und frische Antwort bei jedem Aufruf durch railsbench, lobsters, shipit und btest verglichen, ohne
Abweichung. CI: siehe rote macOS-Jobs oben.

**Gemessen.** `compile_time_ns`, Median aus 6 verschachtelten Läufen gegen master: railsbench −2,3 % (A/A 0,0 % und
−0,6 %), lobsters −2,6 % (A/A −0,8 % und +0,2 %), shipit +0,3 % (A/A +2,8 % und +3,2 %, also im Rauschen; frühere
Runden −2,3 % und −3,8 %). Eine Methode mit 4.000 Aufrufen: 3,53 / 3,48 s → 2,32 s. Das ist Kompilierzeit, nicht
Laufzeit des erzeugten Codes.

### ruby/ruby#19681: Register über C-Aufrufe ohne quadratische Suche finden

[PR](https://github.com/ruby/ruby/pull/19681) · offen · Kopf `dea97c3afa` · löst Shopify/ruby#1065

**Worum es geht.** Vor jedem C-Aufruf muss ZJIT die Register sichern, die Werte über den Aufruf hinweg halten. Dafür
ging es bei jedem C-Aufruf alle Lebensintervalle der Register durch: Aufwand C-Aufrufe mal Intervalle. Der PR
ordnet jedes Intervall einmal per binärer Suche den sortierten C-Aufruf-Positionen zu und legt das Ergebnis in eine
flache Tabelle; jeder C-Aufruf liest seinen Ausschnitt. Die Reihenfolge der gesicherten Register bleibt gleich, also
ist der erzeugte Code identisch.

```ruby
# dasselbe Beispiel wie bei #19680; hier sinkt die Zeit für "big" von etwa 3,5 s auf etwa 1,8 s,
# mit #19680 zusammen laut Issue auf etwa 0,5 s
src = "def big(o)\n  s = 0\n" + ("  s ^= o.hash\n" * 4000) + "  s\nend"
eval src
big(Object.new)
```

**Die harte Frage.** tekknolagi: "Bitte keinen Zwischen-Vec pro C-Aufruf." Antwort: Es gibt keinen; die Puffer
werden wiederverwendet. Und: "Ist der Code wirklich gleich?" Eine Prüf-Build hat alte und neue Liste bei jedem
C-Aufruf durch railsbench, lobsters, shipit und btest verglichen, ohne Unterschied; LIR-Dumps sind identisch. Es ist
eine Zwischenlösung ohne Intervall-Splitting. CI: siehe rote macOS-Jobs oben.

**Gemessen.** `compile_time_ns` gegen master: railsbench −2,9 %, lobsters −5,4 % (beide außerhalb der A/A von
höchstens 0,8 %), shipit +0,3 % (im A/A von bis zu 3,2 %). Instruktionen in `handle_caller_saved_regs` auf
railsbench 558 M → 328 M (−41 %). 4.000-Aufruf-Methode 3,53 / 3,48 s → 1,73 / 1,89 s. Kompilierzeit, nicht Laufzeit.

### ruby/ruby#19682: `super` aus einer Methode mit Block nicht mehr bei jedem Aufruf abbrechen

[PR](https://github.com/ruby/ruby/pull/19682) · offen · Kopf `18aff0c5a4` · zu Shopify/ruby#1100

**Worum es geht.** Wird eine Methode mit Block aufgerufen und ruft sie `super` auf, springt ZJIT bei jedem Aufruf
in den Interpreter zurück. Der spezialisierte `super`-Aufruf prüft, dass der Frame keinen Block hat, und diese
Prüfung kompiliert nie neu. In Rails passiert das z. B. in `ControllerRuntime#cleanup_view_runtime`. Der PR merkt sich
im Profil, ob der Frame einen Block hatte; solche Stellen nehmen den allgemeinen `super`-Weg (wie `super { }` schon
heute), und die Prüfung kompiliert neu, falls später doch ein Block auftaucht.

```ruby
class A; def m = (block_given? ? yield : 0); end
class B < A; def m = super; end # super ohne Klammern reicht den Block weiter
o = B.new
i = 0
while i < 20_000
  o.m { 1 }
  i += 1
end
# ruby --zjit --zjit-stats: exit_unhandled_block_arg master 20.000, mit dem PR 0
```

**Die harte Frage.** "Warum den Block nicht gleich an die Zielmethode durchreichen und voll spezialisieren?"
Antwort: Das bräuchte eine neue Art Block-Handler, die auch das Inlining kennen muss; es bringt das Beispiel auf 555
statt 942 Instruktionen pro Aufruf, bewegt ruby-bench aber nicht. Darum die kleine Version.

**Gemessen.** Side-Exits pro Iteration: railsbench 2.052 → 0, lobsters 341 → 0, shipit 57 → 0. Beispiel mit
explizitem `super`: 1.090 → 942 Callgrind-Instruktionen pro Aufruf (zwei master-Läufe 1.090,4 und 1.090,5, also weit
über dem Rauschen). Instruktionen pro ruby-bench-Iteration: im Rauschen, kein messbarer Effekt auf die Apps.

### ruby/ruby#19685 (Draft): jede ISEQ nur einmal pro GC markieren

[PR](https://github.com/ruby/ruby/pull/19685) · Draft seit 2026-11-03 · Kopf `aa82ba85e1`

**Worum es geht.** Bei jeder Speicherbereinigung, auch den kleinen, geht ZJIT alle JIT-Frames durch und markiert
deren ISEQ als lebendig. ZJIT legt einen JIT-Frame pro Aufrufstelle und Zustand an, also markiert es dieselben
ISEQs immer wieder (railsbench nach dem Aufwärmen: 38.118 Frames). Der PR trägt jede ISEQ beim Anlegen eines Frames
in eine Menge ein und markiert nur die Menge. Sicher, weil JIT-Frames nie freigegeben werden und ihr ISEQ-Zeiger sich
nur beim Kompaktieren ändert; nach dem Kompaktieren wird die Menge neu aufgebaut, wie es `Invariants` für seine
Tabellen tut.

```ruby
# viele kompilierte Aufrufstellen, dann viele kleine GCs; der Effekt wächst mit der Zahl der JIT-Frames
2_000.times { |i| eval "def m#{i}(x) = x + 1; def c#{i}(x) = m#{i}(x) + m#{i}(x)" }
3.times { 2_000.times { |i| send(:"c#{i}", 1) } }
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
1_000.times { GC.start(full_mark: false) }
p Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
# ruby --zjit --zjit-call-threshold=1, einmal master, einmal PR
```

**Die harte Frage.** "Enthält die Menge genau, was die alte Schleife markiert hat, auch nach Kompaktierung?" Antwort:
Ja; zwei Tests prüfen das. Der eine schlägt fehl, wenn das Markieren fehlt (oder nur bei großen GCs passiert), der
andere, wenn die Menge nach dem Kompaktieren nicht neu aufgebaut wird. Ein dritter läuft unter `GC.stress` mit
Auto-Kompaktierung.

**Gemessen.** Callgrind-Instruktionen pro Iteration inklusive GC (`--zjit-exec-mem-size=512 --zjit-mem-size=1024`):
`rb_zjit_root_mark` railsbench 28,5 M → 2,0 M, lobsters 7,0 M → 0,26 M, shipit etwa 40 M → 1,9 M. Ganze Iteration:
railsbench −0,64 % (A/A 0,04 % / 0,03 %), lobsters −0,23 % (A/A 0,07 % / 0,08 %), beide klar über dem Rauschen;
shipit etwa −0,5 %, weniger sicher, weil ein master-Lauf in der langsamen Aufwärmphase lag und herausgenommen wurde.
Instruktionen, keine Zeit.

## ruby/ruby: YJIT

YJIT ist laut XrXr und k0kubun im Wartungsmodus. Performance-PRs für YJIT werden wahrscheinlich nicht gemergt;
Thomas hat entschieden, sie offen zu lassen.

### ruby/ruby#19487: `super` auf Klassen- und Modulmethoden kompilieren

[PR](https://github.com/ruby/ruby/pull/19487) · offen · approved von k0kubun (2026-10-22) · Kopf `4f8f7fe7e7`

**Worum es geht.** YJIT spezialisiert `super` nicht, wenn der Empfänger eine Singleton-Klasse hat, damit der
kompilierte Code den Empfänger nicht am Leben hält. Das schließt jedes `super` aus einer Klassenmethode aus. Der PR
kompiliert `super`, wenn der Empfänger eine Klasse oder ein Modul ist. Dass der Code dann die Klasse festhält, ist
unkritisch, weil Klassen meist ohnehin über eine Konstante erreichbar sind. Andere Objekte mit Singleton-Klasse und
`super` in Blöcken bleiben beim alten Weg.

```ruby
class Base; def self.build = :base; end
class Child < Base; def self.build = super; end
i = 0
while i < 10_000_000
  Child.build
  i += 1
end
# ruby --yjit --yjit-stats: invokesuper_singleton_class master etwa 10 M, mit dem PR 0
```

**Die harte Frage.** "Hält das Klassen unnötig im Speicher?" Antwort: Nur Klassen und Module, die über ihren
Methodeneintrag ohnehin referenziert werden; k0kubun hat genau diesen Kompromiss approved ("As a maintainer of
`ERB::Util.html_escape`, I care about its performance too").

**Gemessen.** `super` auf einer Klasse in einer Schleife 32,6 → 8,2 ms, auf einem Modul 63,8 → 11,6 ms. ruby-bench:
Mittel 0,990 (Spanne 0,970–1,009), also kein messbarer Effekt auf die Apps. Fallbacks pro Iteration railsbench
77.273 → 25.961.

### ruby/ruby#19492: dynamische Sends vor dem Aufruf zählen

[PR](https://github.com/ruby/ruby/pull/19492) · offen · approved von k0kubun · Kopf `1c6d753c71`

**Worum es geht.** `--yjit-stats` zählt zu wenige dynamische Sends: Endet der Aufruf mit einer Exception, `throw`
oder einem `break` aus dem Block, wird der Zähler übersprungen, weil das Hochzählen nach dem Aufruf steht. Der PR
zählt vorher. Ohne `--yjit-stats` erzeugt der Zähler keinen Code, also ändert sich für normale Nutzer nichts.

```ruby
TARGET = Object.new
def TARGET.call = yield # Singleton-Methode: YJIT ruft sie dynamisch auf
def op = (TARGET.call { raise "x" } rescue nil)
100.times { op }
RubyVM::YJIT.reset_stats!
10.times { op }
p RubyVM::YJIT.runtime_stats[:num_send_dynamic] # mit --yjit --yjit-stats: master 0, mit dem PR 10
```

**Die harte Frage.** "Kostet das Laufzeit?" Antwort: Ohne `--yjit-stats` wird kein Code erzeugt; die Messung
0,999 (0,994–1,004) zeigt nur das Rauschen.

**Gemessen.** Diagnose, keine Performance. sequel: `num_send_dynamic` 25.000 → 26.000 pro Iteration, andere Zähler
unverändert.

### ruby/ruby#19620: Rückportierung eines YJIT-Fixes auf Ruby 3.4

[PR](https://github.com/ruby/ruby/pull/19620) · offen · Kopf `626b7bd20c`

**Worum es geht.** Unser gemergter #19554 behebt ein falsches Ergebnis unter YJIT: Ein Block, der über `enum_for`
mit expliziten Keywords aufgerufen wird, bekam die Keywords als positionelles Argument. Ein Reviewer bat um die
Rückportierung auf 3.4; das ist ein unverändertes `git cherry-pick -x`.

```ruby
def values = yield([], key: 1)
p enum_for(:values).to_a
# ruby --yjit --yjit-call-threshold=1 auf ruby_3_4: [[[], 1]]; mit dem Fix: [[[], {key: 1}]] wie der Interpreter
```

**Die harte Frage.** "Warum rückportieren?" Antwort: Es war im Review von #19554 erbeten; es ist ein falsches
Ergebnis, kein Tempo. Die roten CI-Jobs (i686, macOS, bundled gems) sind nicht untersucht.

**Gemessen.** Nichts; Korrektheit.

### ruby/ruby#19648: kein `Ractor::IsolationError` beim Kompilieren

[PR](https://github.com/ruby/ruby/pull/19648) · offen · approved von k0kubun · Kopf `cc33a7d70b`

**Worum es geht.** YJIT liest beim Kompilieren das an eine Singleton-Klasse gebundene Objekt. Seit 17baadc072 wirft
`rb_class_attached_object()` dabei einen Fehler, wenn das Objekt einem anderen Ractor gehört und nicht teilbar ist,
etwa der Block-Parameter-Proxy. Dann scheitert ein normales Programm in einem Ractor nur, weil YJIT kompiliert. Der PR
liest das Objekt mit einer neuen Funktion ohne diese Prüfung; YJIT vergleicht es nur auf Identität und gibt es nie an
Ruby-Code weiter.

```ruby
def call_block(&block) = block.call
p Ractor.new { call_block { :ok } }.value
# ruby --yjit-call-threshold=1: master Ractor::IsolationError, mit dem PR :ok wie der Interpreter
```

**Die harte Frage.** k0kubun: "In `yjit.c` statt `jit.c`?" Erledigt. Eine weitere mögliche: "Umgeht das die
Ractor-Isolation?" Nein, das Objekt wird nur auf Gleichheit des Zeigers geprüft.

**Gemessen.** Nichts; Korrektheit. Gefunden über Rails' `DeprecationTest` unter YJIT.

### ruby/ruby#19663: `Hash.new` in YJIT spezialisieren

[PR](https://github.com/ruby/ruby/pull/19663) · offen · Kopf `251d0561d4` · baut auf #19660 (gemergt) und #19661

**Worum es geht.** Seit #19537 ist `Hash.new` unter YJIT ein gewöhnlicher Aufruf einer C-Funktion. Das ist langsamer
und hat einen Nebeneffekt: Ein Refinement von `Hash#initialize` an der Aufrufstelle wird nicht angewendet, im
Interpreter schon (Shopify/ruby#1101). Der PR macht in YJIT, was der Interpreter tut: Hash anlegen
(`rb_hash_alloc_capa`), dann `#initialize` aus dem Aufrufer senden, solange `Hash.new` nicht umdefiniert ist.

```ruby
module R
  refine Hash do
    def initialize(*) = (super(); self[:refined] = true)
  end
end
using R
def make = Hash.new
p 5.times.map { make }
# ruby --yjit --yjit-call-threshold=1: master [{}, {}, …], mit dem PR [{refined: true}, …] wie der Interpreter
```

**Die harte Frage.** byroot: "Calling `#initialize` is a wasteful thing to do for the JIT. You're likely better to
call `rb_hash_s_new` … directly." Wir haben zurückgefragt, welche der zwei Varianten er will: direkter C-Aufruf
(schneller, aber Refinements an der Aufrufstelle wirken nicht, wie heute auf master) oder Senden aus dem Aufrufer
(wie der Interpreter). **Antwort steht aus (Stand 22:00 UTC).** Dazu kommt XrXrs Hinweis zum Wartungsmodus.

**Gemessen.** YJIT, Nanosekunden pro Aufruf, beste von 7, zwei Läufe: `Hash.new(0)` 134,0 / 115,6 → 60,0 / 66,4,
`Hash.new(capacity: 3)` 248,6 / 233,3 → 97,5 / 105,0, `Hash.new` 122,4 / 116,7 → 88,9 / 94,7. Zeit, deutlich über
der Streuung zwischen den Läufen; kein ruby-bench-Effekt gemessen.

### ruby/ruby#19664: Splat-Array nicht vor dem Zerschneiden kopieren

[PR](https://github.com/ruby/ruby/pull/19664) · offen · Kopf `d531b19421`

**Worum es geht.** Füllt ein Splat erst feste Parameter und der Rest geht in `*rest`, kopierte YJIT das Array und
schnitt dann aus der Kopie den Rest heraus. Der Ausschnitt ist ohnehin ein neues Array, die Kopie also überflüssig;
der Interpreter macht nur eins. Rails ruft so bei jedem `where(...)` (`spawn.where!(*args)` in `where!(opts, *rest)`).

```ruby
def f(a, *rest) = rest
args = [1, 2, 3]
p allocs { f(*args) } # Interpreter: 1, YJIT master: 2, mit dem PR: 1
```

**Die harte Frage.** XrXr: "touches a high risk part of YJIT so we're unlikely to take it." Antwort: verstanden; der
Test prüft, dass der Rest ein normales Array ist (auch bei Array-Unterklassen) und dass Ändern des Rests das Array
des Aufrufers nicht ändert. Ob wir antworten: siehe Teil 1.

**Gemessen.** ruby-bench unter YJIT, Objekte pro Iteration: railsbench −0,07 %, lobsters −0,10 %, shipit −0,13 %;
zwei master-Builds unterscheiden sich um höchstens 0,004 %. Allokationen; Laufzeit nicht messbar beeinflusst.

### ruby/ruby#19665: Integer und Module in YJIT ohne `to_s` interpolieren

[PR](https://github.com/ruby/ruby/pull/19665) · offen · Kopf `89472a2a77` · YJIT-Gegenstück zu #19678

**Worum es geht.** Wie #19678, nur für YJIT: Bei `"#{i}"` und `"#{klass} Update"` sendet YJIT `to_s` und legt einen
String mehr an als der Interpreter. Der PR macht, was der Interpreter (`vm_objtostring`) macht, abgesichert darauf,
dass `to_s` noch das Original ist. Rails interpoliert die Modellklasse in den Instrumentierungsnamen jedes Inserts und
Updates.

```ruby
def update_name(klass) = "#{klass} Update"
p allocs { update_name(String) } # Interpreter: 1, YJIT master: 2, mit dem PR: 1
```

**Die harte Frage.** "Was ist mit Refinements oder umdefiniertem `to_s`?" Antwort: YJIT nimmt den direkten Weg nur,
wenn `to_s` zu `rb_int_to_s` bzw. `rb_mod_to_s` auflöst; sonst wird gesendet. Tests decken Refinements,
Umdefinition, anonyme und Singleton-Klassen ab.

**Gemessen.** ruby-bench unter YJIT, Objekte pro Iteration: shipit −0,21 %, lobsters −0,03 %, railsbench 0; A/A
höchstens 0,004 %. Keine Zeit gemessen.

### ruby/ruby#19666: Splat-Array als Rest-Parameter wiederverwenden

[PR](https://github.com/ruby/ruby/pull/19666) · offen · Kopf `70b8e23a8f`

**Worum es geht.** Bei `f(*a, b)` baut der Aufrufer ein neues Array nur für diesen Aufruf. Der Interpreter gibt es
direkt als `*rest` weiter, weil niemand sonst es kennt; YJIT kopiert es immer. Der PR verwendet es in denselben
Fällen wieder wie der Interpreter. Bei optionalen oder nachgestellten Parametern, `ruby2_keywords` und einigen
`**nil`-Fällen wird weiter kopiert. Rails reicht jede Controller-Action durch eine Kette `def process_action(*) = super`.

```ruby
def f(*rest) = rest
a = [1]
p allocs { f(*a, 2) } # Interpreter: 1, YJIT master: 2, mit dem PR: 1
```

**Die harte Frage.** "Kann jemand anderes das wiederverwendete Array sehen?" Antwort: Nur in den Fällen, in denen
der Interpreter es auch wiederverwendet (der Aufrufer hat es für diesen Aufruf gebaut, oder ein anonymes `*` erhält
genau die Splat-Elemente). Überschneidung mit #19664 in einer `if`-Bedingung, im PR beschrieben.

**Gemessen.** ruby-bench unter YJIT, Objekte pro Iteration: railsbench −0,23 %, lobsters −0,03 %, shipit −0,01 %;
A/A höchstens 0,004 %. `process_action`-Kette 5 → 3 Objekte (Interpreter 2). Keine Zeit gemessen.

## rails/rails

### rails/rails#59557: `Array#index_with` ohne Paar-Arrays auf Ruby 4.1

[PR](https://github.com/rails/rails/pull/59557) · offen · Kopf `9aafb10814`

**Worum es geht.** `index_with` läuft in fast jedem Request (Spaltenindex jedes Abfrageergebnisses, `as_json`,
`save`). Es baut den Hash mit `to_h { [elem, value] }` und legt damit pro Element ein Paar-Array an. Ein früherer
Versuch (#59108) wurde zurückgenommen, weil der wachsende Hash auf 4.1 seine Tabelle früher auf den C-Heap verlegte.
Seit ruby/ruby#19537 hält `Hash.new(capacity:)` die Tabelle eingebettet; auf Ruby 4.1 füllt der PR deshalb einen
vorab dimensionierten Hash. Ruby 4.0 und Array-Unterklassen behalten `to_h`; der Hash ist derselbe.

```ruby
# braucht Ruby 4.1 (master); unter den Rails-Kopf
p allocs { %w[a b c d].index_with { 1 } } # main: 5, mit dem PR: 1 (Interpreter)
```

**Die harte Frage.** "Lohnt ein Zweig nach Ruby-Version, wenn kleine Aufrufe mehr Instruktionen kosten und ZJIT
langsamer wird?" Ehrliche Antwort: Bei 3 Elementen 16 % mehr Instruktionen im Interpreter und 46 % mehr unter ZJIT,
weil ZJIT `Hash.new(capacity:)` noch nicht spezialisiert; erst ab etwa 50 Elementen 13 % weniger. Achtung: Nach
unseren eigenen Regeln von heute wäre ein Ruby-Versionszweig Lesbarkeitsstufe L3 ("don't open"), und ein
ZJIT-Verlust blockiert einen Rails-Kandidaten, bis er erklärt ist. Der PR ist älter als diese Regeln.

**Gemessen.** Ruby 4.1, Interpreter, byroots Heap-Report: Objekte pro Iteration railsbench −12 k, shipit −61 k,
lobsters −5 k; kein `index_with`-Hash bis 8 Einträge zieht auf den C-Heap. Instruktionen pro Aufruf (Callgrind, A/A
höchstens 0,16 %): +16 % bei 3 Elementen, +2,6 % bei `serializable_hash` mit 4 Attributen, −13 % bei 50 Elementen;
ZJIT +46 % bei 3 Elementen. Wall time unverändert.

### rails/rails#59564: Arbeits-Arrays des Preloaders an Ort und Stelle bauen

[PR](https://github.com/rails/rails/pull/59564) · offen · Kopf `2fb737482f`

**Worum es geht.** `Preloader::Batch#call` fragt in jeder Runde jeden Zweig nach künftigen Klassen und
ausführbaren Loadern und baut die Antworten aus Kopien von Kopien. Das bezahlt jedes `preload` und jedes `includes`,
das vorlädt. Der PR baut diese Arrays mit `concat`, `delete_if`, `map!` und `uniq!` an Ort und Stelle. Sicher, weil
alle diese Arrays in derselben Methode (oder von `likely_reflections`) frisch gebaut werden; kein Array, das ein
Aufrufer, Loader oder anderer Zweig hält, wird verändert.

```ruby
p allocs { Post.preload(:comments).to_a } # hier 290 → 281 Objekte, im PR-Benchmark 384 → 375
```

**Die harte Frage.** "Was, wenn jemand `likely_reflections` überschreibt und ein gemerktes Array zurückgibt?"
Antwort: Dann würde `delete_if` dieses Array ändern. Die Methode ist privat (`:nodoc:`); unsere Regeln akzeptieren
das für private Methoden, und Astras 16 Fälle (polymorph, through, verschachtelt, bereits geladen) verhielten sich
wie main.

**Gemessen.** Ruby 4.0.7 (ZJIT: master): `Post.preload(:comments).to_a` 384 → 375 Objekte, Instruktionen −0,14 %
Interpreter (A/A −0,06 %, knapp über dem Rauschen), −0,34 % YJIT (A/A +0,04 %), −0,24 % ZJIT (A/A 0,00 %).
Through-Preload 757 → 730 Objekte, −0,20 % / −0,52 % / −0,49 % (A/A +0,02 / −0,04 / +0,18 %). Klein, aber über dem
Rauschen außer knapp im Interpreter.

### rails/rails#59565: Hinweis auf Casts, wenn PostgreSQL einen Platzhalter nach einem Typnamen ablehnt

[PR](https://github.com/rails/rails/pull/59565) · offen · Kopf `ab69e1b5e7`

**Worum es geht.** Seit #58427 schickt Rails auch `find_by_sql(["SELECT DATE :d", d: x])` mit Prepared Statements
als `DATE $1` an PostgreSQL. PostgreSQL lehnt das mit einem nackten `syntax error at or near "$1"` ab, weil nach
`DATE` nur ein Literal stehen darf. Der PR lässt Fehlerklasse und Meldung gleich und hängt einen Hinweis an: Platzhalter
casten (`CAST($1 AS date)`, `$1::date`), bei `IS` das Literal schreiben oder `IS NOT DISTINCT FROM` nehmen, oder
`sanitize_sql_array`. Der Hinweis erscheint nur, wenn genau an der von PostgreSQL gemeldeten Fehlerposition ein
`$n` direkt nach einem dieser Schlüsselwörter steht.

```ruby
# Kopf mit PostgreSQL statt SQLite: gem "pg" und
# ActiveRecord::Base.establish_connection("postgres://localhost/test") (prepared statements sind Standard)
Post.find_by_sql(["SELECT DATE :d", { d: Date.today }])
# main: ActiveRecord::StatementInvalid: PG::SyntaxError: … syntax error at or near "$1"
# PR:   dieselbe Meldung, dazu der Hinweis auf CAST($1 AS date) / $1::date
```

**Die harte Frage.** "Ist es nicht fragil, im Fehlerfall SQL zu untersuchen?" Antwort: Es wird nur die Stelle
angeschaut, die PostgreSQL als Fehlerposition meldet; dieselben Wörter anderswo, in Strings oder Kommentaren, geben
keinen Hinweis. Andere Fehler und erfolgreiche Abfragen sind unverändert. byroot hatte in #55439 einen solchen Hinweis
angeregt.

**Gemessen.** Nichts; nur die Fehlermeldung ändert sich.

### rails/rails#59569: Alias-Tracker nur für through-Ketten bauen

[PR](https://github.com/rails/rails/pull/59569) · offen · Kopf `fcfadc0ee8`

**Worum es geht.** `AssociationScope#scope` baut für jede Assoziation einen `AliasTracker` und wirft ihn bei einem
direkten `belongs_to` oder `has_many` ungenutzt weg. Das Bauen ist nicht gratis: Es holt sich eine Datenbankverbindung
aus dem Pool und gibt sie zurück, um die maximale Alias-Länge zu lesen. Der PR baut den Tracker erst, wenn die Kette
ein zweites Glied hat, mit denselben Argumenten wie vorher.

```ruby
p allocs { post.association(:comments).reset_scope; post.comments.where(body: "c").to_a }
# ohne reset_scope wäre der Scope zwischengespeichert; hier 153 → 151 Objekte (2 weniger)
```

**Die harte Frage.** "Eine direkte Assoziation holt beim Bauen des Scopes keine Verbindung mehr. Hängt etwas davon
ab?" Antwort: Die Abfrage, die den Scope ausführt, holt die Verbindung weiterhin; nur das Bauen allein (ohne
Ausführung) berührt keine Verbindung mehr. Das steht im PR.

**Gemessen.** Callgrind-Instruktionen pro Aufruf, Ruby 4.0.7, Interpreter / YJIT: `post.author` 692 k / 298 k →
647 k / 282 k (−6,5 % / −5,3 %), `post.comments.to_a` −5,2 % / −4,6 %, mit `where` −4,3 % / −2,9 %. ruby-bench
shipit −2,6 % Interpreter, −1,8 % YJIT (A/A höchstens 0,15 %); railsbench und lobsters im Rauschen
([Messung](activerecord-cpu.md)). Allokationen: 36 von 56 Workloads (Interpreter) und 42 (YJIT) sinken, im A/A
schwanken aber auch 16 bzw. 14.

### rails/rails#59570: unsichere `OutputBuffer`-Anhänge ohne `super`-Umweg escapen

[PR](https://github.com/rails/rails/pull/59570) · offen · Kopf `a2a3bf0075`

**Worum es geht.** Jedes `<%= %>` hängt über `ActionView::OutputBuffer#<<` an. Für einen nicht `html_safe`-Wert
ruft es `ERB::Util.unwrapped_html_escape`, das über einen Alias und ein `super` auf der Singleton-Klasse von
`ERB::Util` bei `ERB::Escape.html_escape` landet. YJIT kann dieses `super` nicht spezialisieren. Der PR macht dieselben
Schritte direkt: `to_s`, `html_safe?`, `ERB::Escape.html_escape`. Jeder `to_s`- und `html_safe?`-Aufruf bleibt.

```ruby
require "action_view"
module Spy
  def unwrapped_html_escape(s) = (puts "gesehen"; super)
end
ERB::Util.singleton_class.prepend(Spy)
buf = ActionView::OutputBuffer.new
buf << "<b>"
puts buf # main: "gesehen", dann &lt;b&gt;; mit dem PR nur &lt;b&gt;
```

**Die harte Frage.** Genau das Beispiel: Ein Modul, das sich vor `ERB::Util` hängt, sieht Template-Anhänge nicht
mehr. #46573 (k0kubun) hat `super` bewusst gewählt, damit solche Prepends funktionieren. Antwort: Das gilt weiter
für alle anderen Aufrufer, nur nicht für Template-Anhänge; `unwrapped_html_escape` ist `:nodoc:`. Es ist ein
Abwägen, das der PR offen benennt und dem Reviewer überlässt.

**Gemessen.** Ruby 4.0.7, ein `<%= %>` eines unsicheren Strings: Interpreter 141 → 110 ns, YJIT 68 → 52 ns.
erubi-rails auf ruby-bench: Instruktionen −5,8 % Interpreter (A/A −0,3 %), −5,3 % / −6,1 % YJIT (A/A +0,5 % /
−0,2 %), klar über dem Rauschen ([Messung](actionview-cpu.md)).

### rails/rails#59574: Positionaler Tabellenname in `Arel::Table.new` wieder erlaubt, mit Deprecation

[PR](https://github.com/rails/rails/pull/59574) · offen · Kopf `79b81aa0bf`

**Worum es geht.** `Arel::Table.new(:users)` funktioniert bis Rails 8.1 und wirft auf main `ArgumentError`, weil
#57829 den Namen zum Keyword `name:` gemacht hat. Arel ist `:nodoc:`, aber Gems und Apps rufen es auf: flipper 1.4.2
(aktuellste Version), Discourse und Docuseal brechen. Der PR nimmt den positionalen Namen wieder an, mit
Deprecation-Warnung, und behandelt ihn genau wie `name:`; beides zusammen wirft einen Fehler.

```ruby
require "active_record"
p Arel::Table.new(:users).name # Rails 8.1: "users"; main: ArgumentError; PR: "users" plus Deprecation-Warnung
p Arel::Table.new(name: :users).name # main und PR: "users"
```

**Die harte Frage.** "Arel ist privat, warum Rücksicht nehmen?" Antwort: Weil die aktuelle flipper-Version und
große Apps sonst auf Rails main brechen, und byroot hat diesen Übergang in #57829 selbst vorgeschlagen.

**Gemessen.** Kompatibilität, keine Performance. Etwa 40 ns mehr pro ungecachter Konstruktion durch den optionalen
Parameter; Requests treffen diesen Weg nicht.

### rails/rails#59577: Spaltenreferenzen in `order` ohne Zwischen-Arrays sammeln

[PR](https://github.com/rails/rails/pull/59577) · offen · Kopf `51c3f20e9f`

**Worum es geht.** `column_references` läuft bei jedem `order` und `reorder` und legt mit `flat_map` und
`filter_map` zwei Arrays an, auch wenn nichts auf eine Tabelle verweist (`order(:id)`). Der PR geht die Argumente
mit derselben `case`-Anweisung durch, legt das Ergebnis erst beim ersten Treffer an und gibt sonst ein gefrorenes
leeres Array zurück, das beide internen Aufrufer nur lesen. Gleiche Aufrufe pro Argument, gleiche Referenzen in
gleicher Reihenfolge.

```ruby
p allocs { Post.order(:id).to_a } # hier 86 → 82 Objekte, im PR-Benchmark 106 → 102
```

**Die harte Frage.** fatkodima: "What is a real world performance impact of this? … more complex and uglier for
questionable benefits." Thomas hat geantwortet: Auswahl aus einem Allokations-Zensus, pro Aufruf messbar, für eine
ganze App allein nicht messbar; die Summe vieler solcher PRs schon (22 PRs, 3,3 % weniger Allokationen); und der PR
wurde auf den kleineren Teil verkleinert (+16/−3). Mehr gibt es nicht zu sagen, solange er nicht nachfragt.

**Gemessen.** Pro Aufruf `preprocess_order_args([:id])`: 11 → 7 Objekte, Instruktionen −5,3 % Interpreter, −16 %
YJIT, −15 % ZJIT. Ganzes `Post.order(:id).to_a`: −0,6 % Interpreter (etwa das Rauschen), YJIT im Rauschen, ZJIT
−2,5 %. Auf ruby-bench nicht sichtbar (railsbench ruft `order` nicht).

### rails/rails#59583: Fremdschlüssel einer through-Assoziation lesen ohne ihn in ein Array zu packen

[PR](https://github.com/rails/rails/pull/59583) · offen · Kopf `44048a385c`

**Worum es geht.** Jeder Lesezugriff auf eine geladene `has_one :through` oder `has_many :through` über ein
`belongs_to` prüft `stale_state`, also die Fremdschlüsselwerte des Besitzers. Für einen einspaltigen Schlüssel packt
Rails den Spaltennamen in ein Array, mappt in ein zweites und ruft `presence`. Der PR liest bei einem einfachen
String-Schlüssel die Spalte direkt und packt nur den Wert ein. Zusammengesetzte Schlüssel und String-Unterklassen
behalten den alten Code; das Ergebnis und die Zahl der `read_attr`-Aufrufe sind gleich.

```ruby
comment = Comment.first
comment.post_author # laden
p allocs { comment.post_author } # main 3, mit dem PR 1
```

**Die harte Frage.** "Warum `instance_of?(String)` statt `is_a?`?" Antwort: Eine String-Unterklasse mit `to_ary`
würde von `Array(...)` anders behandelt; der Gegentest hat das gezeigt, darum bleiben Unterklassen auf dem alten Weg.

**Gemessen.** Pro Aufruf: 3 → 1 Objekte; Instruktionen Interpreter 15.447 → 12.076 (−22 %), YJIT 8.283 → 4.983
(−40 %), ZJIT 7.879 → 4.571 (−42 %); Wiederholung von main höchstens +0,20 %, also weit über dem Rauschen. 16
Workloads in 5 Apps allokieren weniger (z. B. etwa 250 Objekte weniger pro Discourse-Themenliste).

### rails/rails#59584: JSON aus `JSON::Coder` escapen, indem nach jedem Zeichen einzeln gesucht wird

[PR](https://github.com/rails/rails/pull/59584) · offen · Kopf `8f77e334e9`

**Worum es geht.** Vor Ruby 4.1 escapt `JSONGemCoderEncoder` (Standard mit json ≥ 2.15.2) `<`, `>`, `&`, U+2028 und
U+2029 mit einem `gsub!` über einen vereinigten regulären Ausdruck; der läuft über das ganze Dokument, auch wenn nichts
zu escapen ist. Der PR sucht mit `include?` nach jedem Zeichen und ersetzt nur, was vorkommt. Die Ausgabe ist gleich:
Die Ersetzungen enthalten keines der fünf Zeichen, also stört eine Ersetzung die nächste nicht, und die Suche läuft
weiter auf dem Binär-String. Ruby 4.1 nutzt ohnehin `tr!`; ältere Encoder behalten das eine `gsub!`.

```ruby
# Ruby 4.0, json >= 2.15.2, unter den Rails-Kopf
puts({ a: "<b> & </b>", b: "plain" }.to_json)
# main und PR identisch: {"a":"\u003cb\u003e \u0026 \u003c/b\u003e","b":"plain"}
```

**Die harte Frage.** "Warum fünf Suchen statt einem regulären Ausdruck, und ist die Reihenfolge der Ersetzungen
egal?" Antwort: `include?` ist eine schnelle Byte-Suche; der reguläre Ausdruck startet die Regex-Maschine für jedes
Zeichen. Die Reihenfolge ist egal, weil keine Ersetzung eines der fünf Zeichen erzeugt; die Einstellungen werden wie
auf main vor dem Ersetzen gelesen.

**Gemessen.** Ruby 4.0.7, 20 Datensätze mit 11 Spalten, Instruktionen (Wiederholung von main höchstens 0,2 %, nur
`render json:` unter YJIT 1,8 %): `posts.to_json` −4,5 % Interpreter, −6,1 % YJIT; jbuilder −2,9 % / −6,1 %;
`render json:` vor 8.1 −6,0 % / −7,0 %; Text mit `<b>` und `&` −14,1 % / −15,4 %. ruby-bench railsbench unter YJIT
−0,28 % und −0,76 % (A/A −0,08 % / +0,04 %); der Rest im Rauschen.

### rails/rails#59585: `TimeZoneConverter` und `EnumType` einfrieren, wenn das Umhüllte gefroren ist

[PR](https://github.com/rails/rails/pull/59585) · offen · Kopf `2236cd5626`

**Worum es geht.** Die Standardattribute eines Modells werden nur dann über den Schema-Kontext geteilt, wenn sie
Ractor-teilbar sind; sonst sucht jeder Zugriff auf `attribute_types` sie im Ractor-lokalen Speicher. Der
`TimeZoneConverter` (umhüllt jede datetime-Spalte, standardmäßig an) und `EnumType` werden nie eingefroren, also nimmt
fast jedes Modell den langsamen Weg. Der PR friert den Converter ein, wenn sein Subtyp schon gefroren ist, und den
`EnumType`, wenn Mapping und Subtyp es sind. Rails friert die Spaltentypen selbst schon ein (#54228, #55606).

```ruby
p Post.attribute_types["created_at"].frozen? # main false, mit dem PR true
p Post.attribute_types["status"].frozen?     # EnumType: main false, mit dem PR true
```

**Die harte Frage.** "Friert das versehentlich etwas Fremdes ein?" Antwort: Einen Delegator einzufrieren friert auch
das Umhüllte ein; darum nur, wenn der Subtyp schon gefroren ist. Unterklassen des Converters bleiben ungefroren, weil
sie eigenen Zustand haben könnten. Zweite Frage: ZJIT. Ein Modell, das auf dem langsamen Weg bleibt, während andere
umziehen, braucht bis zu 4,6 % mehr Instruktionen pro Zugriff, weil ZJIT diesen Zweig ohne Profil kompiliert; beide
gemessenen Apps sind insgesamt trotzdem schneller.

**Gemessen.** Ruby 4.0.7, Instruktionen (Wiederholung von main höchstens 0,4 %): `Post.attribute_types` −40 %
Interpreter, −45 % YJIT; `Post.new` −8,6 % / −14 %; 10 Zeilen laden −4,1 % / −4,9 %. ruby-bench −0,13 % bis
−0,23 % (Interpreter; railsbench und shipit unter YJIT; A/A höchstens 0,04 %), lobsters unter YJIT im Rauschen;
ZJIT lobsters −0,20 % (A/A +0,11 %). 223 von 312 Modellen in elf Apps ziehen auf den geteilten Weg.
