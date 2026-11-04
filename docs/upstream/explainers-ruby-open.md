# Unsere 13 offenen ruby/ruby-PRs: Erklärung für Thomas, mit Behalten/Schließen

Stand: 2026-11-04, 11:30 UTC. Die Liste kommt aus
`gh pr list -R ruby/ruby --author thomasklemm --state open`. Es sind die 13 genannten PRs, 12 davon bereit und
#19685 als Draft. Alle sind konfliktfrei mergebar. Diffs, Reviews und CI stammen aus `gh`. Gepostet oder geschlossen
wurde nichts.

Thomas führt das Review-Gespräch auf ruby/ruby selbst ([DECISIONS](../DECISIONS.md#playbook-from-the-pr-retrospective-2026-11-04)).
Diese Seite soll ihm das in jedem Detail möglich machen. Zu jedem PR stehen hier: was falsch war (mit Beispiel), was
der PR ändert (mit den entscheidenden Diff-Zeilen), warum das sicher ist, die wahrscheinlichste Reviewer-Frage mit
Antwort, der aktuelle Stand und das Urteil nach dem Playbook.

**Wie die Beispiele geprüft wurden.** „vorher“ ist auf einem eigenen Build von master `fef67df224` (2026-11-04,
`--enable-yjit --enable-zjit`, Release-Build) und auf Ruby 4.0.9 ausgeführt. „nachher“ kommt von einem Build des
jeweiligen PR-Heads mit demselben Skript. Wo „nachher“ aus dem PR-Text stammt, steht das dabei.
`allocs` ist in allen Beispielen diese Hilfsmethode:

```ruby
GC.stat(:total_allocated_objects)
def allocs
  3.times { yield }   # aufwärmen (kompiliert wird über das 100.times in jedem Beispiel)
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
end
allocs { }            # der erste Aufruf legt selbst ein Objekt an
```

## Begriffe

* **ISEQ**: der Bytecode einer Methode oder eines Blocks. **HIR/LIR**: ZJITs Zwischendarstellungen (hoch- und
  niedrigstufig), aus denen der Maschinencode entsteht.
* **Guard**: eine Laufzeitprüfung im kompilierten Code. Scheitert sie, folgt ein **Side-Exit**: Rücksprung in den
  Interpreter. Ein Side-Exit mit `recompile` lässt die Stelle später neu kompilieren; ohne bleibt er dauerhaft.
* **Patch-Point**: eine Annahme (z. B. „`to_s` wurde nicht umdefiniert“), deren Verletzung den Code verwirft.
* **Profil**: was ZJIT vor dem Kompilieren an einer Stelle beobachtet hat (Klassen, Block ja/nein).
* **AR-Tabelle**: die kleine, im Hash-Objekt eingebettete Tabelle für wenige Einträge; größere Hashes nutzen eine
  `st_table`.
* **ICLASS**: der interne Eintrag, mit dem ein eingebundenes Modul in der Vorfahrenkette steht. **IFUNC**: ein Block,
  der in C statt in Ruby implementiert ist (z. B. aus `enum_for`).
* **Kompaktieren**: die GC verschiebt Objekte; Zeiger darauf müssen danach aktualisiert werden.
* **`zjit_alloc_bytes`**: Speicher, den ZJIT selbst belegt. **A/A**: zwei gleiche Builds gemessen; ihre Differenz ist
  das Rauschen.
* **SHSTK, MMTk, i686, s390x**: Sonder-CI-Konfigurationen (Shadow-Stack, alternativer GC, 32 Bit, IBM Z).

## Vorschlag auf einen Blick

Das Limit sind 10 offene PRs. Drei zu schließen bringt uns auf genau 10.

| PR | Bereich | Was | Stand | Vorschlag |
| --- | --- | --- | --- | --- |
| [#19483](https://github.com/ruby/ruby/pull/19483) | ZJIT | `protected`-Aufrufe direkt | kein Review seit 13 Tagen | **schließen** |
| [#19487](https://github.com/ruby/ruby/pull/19487) | YJIT | `super` in Klassenmethoden | approved (k0kubun) | behalten |
| [#19492](https://github.com/ruby/ruby/pull/19492) | YJIT | Statistikzähler vor dem Aufruf | approved (k0kubun) | behalten |
| [#19620](https://github.com/ruby/ruby/pull/19620) | YJIT, 3.4 | Backport eines Korrektheitsfixes | kein Review | behalten |
| [#19648](https://github.com/ruby/ruby/pull/19648) | YJIT | Ractor-Fehler beim Kompilieren | approved (k0kubun) | behalten |
| [#19655](https://github.com/ruby/ruby/pull/19655) | ZJIT | leeres `*` ohne neues Array | kein Review | **schließen** |
| [#19659](https://github.com/ruby/ruby/pull/19659) | ZJIT | Blöcke mit überzähligen Argumenten | kein Review | behalten |
| [#19670](https://github.com/ruby/ruby/pull/19670) | VM | ein Hash statt zwei (Regression in 4.1) | kein Review | behalten |
| [#19678](https://github.com/ruby/ruby/pull/19678) | ZJIT | Interpolation ohne `to_s` | im Review | behalten |
| [#19681](https://github.com/ruby/ruby/pull/19681) | ZJIT | Kompilierzeit bei C-Aufrufen | kein Review | behalten |
| [#19682](https://github.com/ruby/ruby/pull/19682) | ZJIT | `super` mit Block ohne Dauer-Exit | approved (k0kubun) | behalten |
| [#19685](https://github.com/ruby/ruby/pull/19685) | ZJIT | ISEQs einmal pro GC markieren (Draft) | Draft | **schließen** |
| [#19699](https://github.com/ruby/ruby/pull/19699) | ZJIT-Test | wackliger Test aus unserem #19484 | kein Review | behalten |

Die vier Playbook-Regeln, nach denen geurteilt wird:

1. **Wirkung außerhalb A/A.** Ein ZJIT-Performance-PR braucht einen Effekt in `run_benchmarks.rb`, der größer ist als
   der Unterschied zwischen zwei gleichen Builds. Ausnahmen: Das Team hat die Änderung erbeten, oder sie beseitigt einen
   dauerhaften Side-Exit. Korrektheitsfixes brauchen stattdessen einen Repro.
2. **YJIT im Wartungsmodus.** YJIT bekommt nur noch Korrektheitsfixes. Unsere schon offenen YJIT-PRs bleiben offen,
   darüber entscheiden die Maintainer (Entscheidung von Thomas).
3. **Ein Anliegen pro PR.** VM, YJIT oder ZJIT, nie zwei davon, und kein Stapeln auf offene PRs.
4. **Thomas kann ihn erklären.** Jede Review-Frage beantwortet er selbst, in eigenen Worten.

**Wenn das Limit noch enger wird:** Als nächster Kandidat wäre #19487 zu schließen. Es ist der einzige verbleibende
YJIT-Performance-PR und hat keinen ruby-bench-Effekt. Er ist aber approved, und Thomas hat entschieden, dass bei den
YJIT-PRs die Maintainer entscheiden. Darum steht er hier auf „behalten“.

## CI auf den Heads

Gelesen am 2026-11-04 gegen 11:15 UTC. „Nicht unseres“ heißt: Der Fehler liegt in einem Teil, den der PR nicht
berührt, oder er scheitert auf master oder auf fremden PRs genauso.

| PR | Head | Ergebnis | Rote Jobs und warum |
| --- | --- | --- | --- |
| #19483 | `70a47d2cad` | grün | — |
| #19487 | `4f8f7fe7e7` | grün | — |
| #19492 | `1c6d753c71` | 1 rot, nicht unseres | `check (mmtk, release, macos-26)` vom 2026-10-23; GitHub-Annotation: „The hosted runner lost communication with the server.“ |
| #19620 | `626b7bd20c` | 2 rot, nicht unseres | i686: `[BUG]` in `test_gc.rb` (auf i686 wird YJIT gar nicht gebaut); macOS bundled gems: Timeout im `debug`-Gem |
| #19648 | `cc33a7d70b` | 3 rot, nicht unseres | SHSTK: vier `JSONGeneratorTest#test_rfc8785_*`, damals auch auf master rot (inzwischen ist master grün); bundled gems: IRB-Tests |
| #19655 | `852298882d` | grün | — |
| #19659 | `bfb53d473e` | 1 rot, nicht unseres | SHSTK: dieselben vier JSON-Tests |
| #19670 | `eb01818c3d` | 3 rot, nicht unseres | Windows `OpenSSL::TestSSL#test_read_with_timeout`, s390x `TestGemResolverGitSet`, macOS bundled gems (IRB) |
| #19678 | `4944f1a29e` | grün, Haiku läuft noch | der Haiku-Job läuft seit 06:13 UTC |
| #19681 | `dea97c3afa` | 1 rot, **unseres** | `zjit-check` auf macOS: `test_send_proc_block_arg_to_block_param_callee` („Program side-exited“). Der Test stammt aus unserem gemergten #19484, #19699 repariert ihn |
| #19682 | `0442275697` | grün | — |
| #19685 | `aa82ba85e1` | grün | — |
| #19699 | `642bcc8f5e` | grün | — |

Ohne Schreibrechte kann Thomas Jobs nicht selbst neu starten; das kann nur ein Maintainer. Wir pushen nicht nur wegen fremder roter Jobs
(DECISIONS: „Keep open PRs mergeable“).

---

## VM (Interpreter)

### #19670: ein Hash statt zwei für `m(a: v, **h)`, Regression in 4.1

[PR](https://github.com/ruby/ruby/pull/19670) · Head `eb01818c3d` · +55/−9 in 7 Dateien · kein Review

**Was falsch war.** Ruby 4.0 legt für `m(a: v, **h)` einen Hash an, master legt zwei an. Seit byroots #18344
(f01bf185f6) baut Prism die dynamischen Schlüssel (`a: v`) erst mit `newhash` in einen frischen Hash. Beim
Zusammenführen mit `**h` kopiert `core#hash_merge_kwd` diesen frischen Hash dann noch einmal. Dasselbe passiert bei
`super` ohne Klammern in einer Methode mit benannten Keywords.

```ruby
def m(**kw) = nil
h = { b: 2 }
v = 1
p allocs { m(a: v, **h) }   # 4.0.9: 1, master: 2, PR: 1

class P; def z(a: 1, b: 2) = nil; end
class C < P; def z(a: 1, b: 2) = super; end
c = C.new
p allocs { c.z(a: v) }      # 4.0.9: 1, master: 2, PR: 1
```

**Was der PR ändert.** Eine neue interne Methode `core#hash_merge_fit_kwd` führt `**h` direkt in den frischen Hash
ein, wenn das Ergebnis noch in die eingebettete Tabelle (AR-Tabelle) dieses Hashs passt. Wie viele Einträge das sind,
hängt von der Slot-Größe des Hashs ab; bei einem frischen kleinen Hash sind es auf x86_64 **2**. Passt es nicht, kopiert
sie wie bisher in einen neuen, passend großen Hash. Beim `super` ohne Klammern baut jetzt ein einziges `newhash` alle
Keywords auf einmal, statt einen leeren Hash anzulegen und ihn dann mit `hash_merge_ptr` in einen zweiten, neuen Hash
zu kopieren. Hat die Methode `**kwrest`, bleibt es beim alten Weg.

**Wichtig: der PR behebt die Regression nur für kleine Ergebnisse.** Gemessen auf einem Build des PR-Heads, `m(a: v,
**h)` mit `h` von 0 bis 9 Einträgen:

```ruby
r = (0..9).map do |n|
  h = (1..n).to_h { |i| [:"k#{i}", i] }
  allocs { m(a: v, **h) }
end
p r
# 4.0.9:  [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
# master: [2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
# PR:     [1, 1, 2, 2, 2, 2, 2, 2, 2, 2]
```

```c
// hash.c
VALUE
rb_hash_merge2_fit(VALUE h1, VALUE h2)
{
    bool fits = !RHASH_AR_TABLE_P(h1) || RHASH_SIZE(h1) + RHASH_SIZE(h2) <= RHASH_AR_TABLE_MAX_BOUND(h1);
    return rb_hash_merge2(h1, h2, !fits);   // dup = !fits
}
```

```c
// prism_compile.c, pm_compile_hash_elements
-                        PUSH_SEND(ret, location, id_core_hash_merge_kwd, INT2FIX(2));
+                        PUSH_SEND(ret, location, fresh_hash ? id_core_hash_merge_fit_kwd : id_core_hash_merge_kwd, INT2FIX(2));
```

**Warum das sicher ist.** Den Hash, in den gemergt wird, hat dieselbe Befehlsfolge gerade erst mit `newhash` angelegt.
Niemand sonst hat eine Referenz darauf, also darf man ihn verändern. `fresh_hash` ist nur gesetzt, wenn der Hash aus
`newhash` stammt. Beginnt der Hash mit einer gefrorenen Literal-Vorlage, bleibt der alte Weg (`hash_merge_ptr`); dafür
gibt es einen Kontroll-Test. Reihenfolge der Auswertung, Schlüsselreihenfolge, das Überschreiben doppelter Schlüssel und
die Umwandlung mit `to_hash` (`rb_to_hash_type`) sind dieselben wie vorher, weil darunter weiter `rb_hash_merge2` läuft.

**Wahrscheinlichste Frage.** „Warum legt 4.0 bei jedem `**h` nur einen Hash an, der PR aber ab zwei Einträgen in `h`
wieder zwei? Warum nicht immer in den frischen Hash mergen?“ Darauf hat der PR **keine gute Antwort**. Seine Begründung
(im Code-Kommentar): Passt das Ergebnis nicht in den Slot, müsste der Hash auf eine `st_table` umziehen, und dann sei
eine Kopie in einen passend großen Hash nicht teurer. Gemessen ist das nicht, und die Kopie ist ein Ruby-Objekt mehr.
Empfehlung: Fragt ein Reviewer danach, einfach immer in den frischen Hash mergen (wie 4.0) und das Ergebnis mit
derselben Zählung zeigen, statt zu argumentieren. Thomas kann das auch vorher entscheiden. Zweite mögliche Frage (byroot): „Sind das zwei Anliegen
(Aufruf und `super`)?“ Antwort: Es ist dieselbe Regression aus #18344. Beide Fälle legen auf 4.0 einen Hash an und auf
master zwei, siehe Beispiel.

**Stand.** Kein Review, keine Kommentare. CI: drei rote Jobs, keiner unseres (siehe oben). Wir warten auf ein Review.
Naheliegender Reviewer wäre byroot, er hat #18344 geschrieben.

**Playbook.**
* Wirkung: Das ist eine Regression gegenüber 4.0 in einer noch nicht veröffentlichten Version, mit exaktem Repro. Die
  Messung ist eine Allokationszählung: über 97 Rails-Workloads 78.103 Hashes auf 4.0.7, 81.992 auf master und 77.840
  mit dem PR. Zeit wurde nicht gemessen.
* YJIT-Regel: greift nicht; es ist eine reine VM-Änderung und wirkt in allen Modi (Interpreter, YJIT, ZJIT: je 1 im ersten Beispiel).
* Ein Anliegen: ja. Beide Compiler (Prism und `compile.c`), eine neue interne Methode in `vm.c` und eine Hash-Funktion, alles für dieselbe Regression.
* Erklärbar: ja, wenn Thomas die Grenze kennt: Die AR-Tabelle eines frischen kleinen Hashs fasst nur 2 Einträge, darüber bleibt es bei zwei Hashes.

**Vorschlag: behalten.** Das ist eine kleine Regression in 4.1 mit Repro, und 4.1 erscheint im Dezember. Der Fix ist aber
unvollständig (siehe oben); Thomas sollte vor dem Review wissen, dass die naheliegende Frage genau das trifft.

---

## ZJIT

### #19483: `protected`-Aufrufe direkt kompilieren

[PR](https://github.com/ruby/ruby/pull/19483) · Head `70a47d2cad` · +264/−12 in 4 Dateien · seit 2026-10-22 ohne
Review

**Was falsch war.** Eine `protected`-Methode darf mit explizitem Empfänger (`other.cents`) nur aufgerufen werden, wenn
das `self` des Aufrufers eine Instanz der Klasse ist, die die Methode definiert. ZJIT prüft das nicht selbst. Darum lässt
es jeden solchen Aufruf auf dem langsamen allgemeinen Weg, auch wenn Klasse und Zielmethode bekannt sind.

```ruby
class Money
  def initialize(cents) = @cents = cents
  def ==(other) = cents == other.cents   # other.cents ist ein protected-Aufruf
  protected def cents = @cents
end
a, b = Money.new(1), Money.new(1)
i = 0
while i < 1_000_000
  a == b
  i += 1
end
# ruby --zjit --zjit-stats: send_not_optimized_need_permission
#   master 999.971, PR 0 (die Zeile fehlt dann in der Ausgabe)
```

**Was der PR ändert.** Für einen `protected`-Aufruf ohne implizites `self` merkt sich ZJIT die definierende Klasse
(`protected_class`). Nach dem Typ-Guard auf den Empfänger setzt es einen zweiten Guard: `IsA` auf das `self` des
Aufrufers. Schlägt er fehl, springt der Code zurück in den Interpreter, der dann den richtigen `NoMethodError` wirft.
Refinements, per Alias definierte protected-Methoden und Aufrufe aus eingebetteten (inlined) Frames bleiben beim alten
Weg.

```rust
// hir.rs, guard_protected_send
let caller_self = self.load_self(block);
let defined_class = if defined_class.builtin_type() == RUBY_T_ICLASS { defined_class.class_of() } else { defined_class };
let class = self.push_insn(block, Insn::Const { val: Const::Value(defined_class) });
let allowed = self.push_insn(block, Insn::IsA { val: caller_self, class });
self.push_insn(block, Insn::GuardBitEquals { val: allowed, expected: Const::Value(Qtrue),
    reason: Box::new(SideExitReason::ProtectedCheckFailed), state, recompile: None });
```

**Warum das sicher ist.** Der Guard prüft genau das, was die VM prüft: `rb_obj_is_kind_of(self des Aufrufers,
definierende Klasse)`. Ist die Methode in einem Modul definiert, steht dort eine ICLASS; der PR nimmt dann das Modul
selbst. Fehlt `self` als SSA-Wert, also in eingebetteten Frames, wird nicht optimiert.

**Wahrscheinlichste Frage.** „Was bringt das auf ruby-bench?“ Antwort: Die Fallbacks verschwinden fast ganz
(railsbench 1.374.055 → 49 pro Lauf), und die Callgrind-Instruktionen sinken um 0,2 bis 0,6 %. Die Laufzeit in
`run_benchmarks.rb` bleibt aber innerhalb der Streuung zweier master-Builds. Zweite Frage: „Warum `recompile: None`?“
Antwort: Wenn der Guard fehlschlägt, wirft der Interpreter `NoMethodError`. Ein Programm, das das ständig tut, ist kein
Fall, für den sich Neukompilieren lohnt.

**Stand.** Kein Review in 13 Tagen. CI grün. Wir warten auf irgendeine Reaktion.

**Playbook.**
* Wirkung: **nicht erfüllt.** Es ist ein Performance-PR, `run_benchmarks.rb` zeigt nichts außerhalb A/A, das Team hat
  nicht darum gebeten, und es entfernt keinen dauerhaften Exit.
* Ein Anliegen: ja.
* Größe: 264 Zeilen, davon etwa 46 Code (der Rest Tests), ein neuer Side-Exit-Grund und Guards an zehn Stellen in
  `hir.rs`. Mit den Tests liegt er über der Grenze von etwa 150 Zeilen, ab der wir erst auf dem Tracker fragen.
* Erklärbar: ja, aber die zehn Einfügestellen muss Thomas einzeln vertreten können.

**Vorschlag: schließen.** Zehn neue Guard-Stellen ohne messbare Laufzeitwirkung, nicht erbeten und seit 13 Tagen ohne Antwort.

> Thanks to everyone who looked at this. I'm closing it: almost all of these generic sends go away, but
> `run_benchmarks.rb` doesn't change beyond the spread between two master builds, so the extra guards aren't worth
> carrying.

### #19655: leeres anonymes `*` ohne neues Array

[PR](https://github.com/ruby/ruby/pull/19655) · Head `852298882d` · +55/−2 in 4 Dateien · kein Review

**Was falsch war.** Eine Methode mit anonymem Rest-Parameter (`def f(*)`) bekommt bei einem Aufruf ohne zusätzliche
Argumente ein leeres Array. Der Interpreter gibt dafür seit 43683e1e9d ein gemeinsames gefrorenes leeres Array weiter.
ZJIT legt jedes Mal ein neues an. (YJIT auch, aber dieser Teil wurde wegen des Wartungsmodus aus dem PR entfernt.)

```ruby
def f(*) = itself      # nicht "= nil": eine Methode, die nur nil liefert, bettet ZJIT ein, dann gibt es kein Array
def call_f = f
100.times { call_f }
p allocs { call_f }    # Interpreter: 0, ZJIT master: 1, ZJIT PR: 0 (YJIT: 1)
```

**Was der PR ändert.** Wenn ZJIT einen Aufruf direkt kompiliert (`SendDirect`) und der Rest-Parameter leer, anonym und
ohne nachfolgende Parameter ist und der Aufrufer nicht splattet, übergibt es die Konstante `rb_cArray_empty_frozen`
statt ein neues Array zu bauen. Das ist dieselbe Bedingung, die der Interpreter in `vm_args.c` verwendet.

```rust
// hir.rs, plan_send_direct_rest_parameter
-        packed_args.push(SendDirectArg::RestArray(rest_elements));
+        if rest_elements.is_empty() && params.flags.anon_rest() != 0 && post_num == 0 && !has_caller_splat {
+            packed_args.push(SendDirectArg::Constant(unsafe { rb_cArray_empty_frozen }));
+        } else {
+            packed_args.push(SendDirectArg::RestArray(rest_elements));
+        }
```

**Warum das sicher ist.** Ein anonymes `*` hat keinen Namen. Die Methode kann es nur als `*` weiterreichen, nie ändern
oder als Objekt sehen. Das Weiterreichen (`rest(*)`) baut beim Empfänger ohnehin ein neues Array; der Test prüft, dass
`named1 << 1` das gemeinsame Array nicht verändert.

**Wahrscheinlichste Frage.** „In einem Fall allokiert ZJIT jetzt weniger als der Interpreter (`def f(a = nil, *)` mit
`f(1)`). Ist das sichtbar?“ Antwort: Nein, aus demselben Grund: Das leere, namenlose Array kann niemand sehen. Der
Interpreter allokiert dort nur, weil `args_copy` vor dem Füllen des optionalen Parameters läuft.

**Stand.** Kein Review. CI grün.

**Playbook.**
* Wirkung: **nicht erfüllt.** Es spart Objekte (ruby-bench unter ZJIT 0,12 bis 0,17 % weniger pro Iteration), aber eine
  Laufzeitwirkung ist nicht gezeigt, und das Team hat nicht darum gebeten.
* Ein Anliegen: ja, seit der YJIT-Teil entfernt ist.
* Erklärbar: ja, der PR ist klein.

**Vorschlag: schließen.** Klein und richtig, aber ohne den Effekt, den die Regel verlangt. Der Befund bleibt in
unseren Docs; braucht ihn das Team, ist er schnell wieder gebaut.

> Thanks for considering this. I'm closing it: it saves one Array per call that passes nothing to `*`, but I couldn't
> show a ruby-bench speedup beyond noise.

### #19659: Blöcke mit überzähligen Argumenten direkt aufrufen

[PR](https://github.com/ruby/ruby/pull/19659) · Head `bfb53d473e` · +259/−14 in 4 Dateien (Code etwa 15 Zeilen, der
Rest Tests) · löst Shopify/ruby#1094, das tekknolagi selbst angelegt hat · kein Review

**Was falsch war.** `n.times { }` übergibt dem Block ein Argument, das der Block nicht deklariert. Ein normaler Block
(kein Lambda) wirft überzählige Argumente einfach weg. ZJIT rief einen Block bisher nur direkt auf, wenn die Anzahl genau
passte (`argc == lead_num`); sonst nahm es den allgemeinen `invokeblock`-Weg.

```ruby
def run = 1_000.times { }
def runi = 1_000.times { |i| }
200.times { run; runi }
t = Process.clock_gettime(Process::CLOCK_MONOTONIC); 2_000.times { run }; a = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
t = Process.clock_gettime(Process::CLOCK_MONOTONIC); 2_000.times { runi }; b = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
p [(a / 2e6 * 1e9).round(1), (b / 2e6 * 1e9).round(1)]
# ruby --zjit, ns pro Iteration: master [21.5, 4.6], PR [4.9, 5.1]
```

**Was der PR ändert.** ZJIT ruft den Block jetzt auch direkt auf, wenn mehr Argumente kommen, als er deklariert, und
übergibt nur die ersten `lead_num`. Die übrigen werden trotzdem ausgewertet, nur nicht übergeben. Zwei Fälle bleiben
beim alten Weg: ein einzelnes Argument an `|a, b|` oder `|a,|` (das könnte automatisch entpackt werden) und zu wenige
Argumente (die werden mit `nil` aufgefüllt).

```rust
// hir.rs, can_direct_invoke_block_iseq
-    if argc != lead_num {
+    if argc < lead_num {
-    if argc == 1 && !unsafe { rb_get_iseq_flags_ambiguous_param0(iseq) } {
+    if argc == 1 && lead_num > 0 && !unsafe { rb_get_iseq_flags_ambiguous_param0(iseq) } {
// codegen.rs, gen_invoke_block_iseq_direct
+    let args = &args[..lead_num];
```

**Warum das sicher ist.** Der Interpreter (`vm_callee_setup_block_arg`) und YJIT machen genau das. Der Block ist über
seine ISEQ abgesichert (Guard). Es betrifft nur „einfache“ Blöcke (`rb_simple_iseq_p`: keine optionalen Parameter,
kein `*rest`, keine Keywords, kein `&blk`). Lambdas kommen über `&lambda` als Proc an, nicht als ISEQ-Block, und werfen
weiter `ArgumentError`; dafür gibt es einen Test.

**Wahrscheinlichste Frage.** „Warum ändert der PR zwei bestehende Tests?“ Antwort: Dort ist das `yield` in
`Kernel#then` jetzt ein direkter Aufruf, der auf die Block-ISEQ prüft. Jeder Aufruf übergab einen neuen Literalblock,
also sprang der Test heraus. Die Tests rufen jetzt über eine Hilfsmethode, damit die Block-ISEQ dieselbe bleibt. Zweite
mögliche Frage: „Und `|a, *rest|`?“ Antwort: Das ist kein einfacher Block und bleibt beim alten Weg.

**Stand.** Kein Review. CI: ein roter Job (SHSTK, JSON-Tests), nicht unseres.

**Playbook.**
* Wirkung: Die Laufzeit auf ruby-bench ändert sich nicht. Das Team hat das aber selbst als Issue angelegt
  (Shopify/ruby#1094, aus tekknolagis Beobachtung auf unserem #19625). Die Ausnahme „vom Team erbeten“ greift.
* Ein Anliegen: ja.
* Erklärbar: ja, die Code-Änderung sind wenige Zeilen.

**Vorschlag: behalten.**

### #19678: Integer und Module interpolieren, ohne `to_s` zu senden

[PR](https://github.com/ruby/ruby/pull/19678) · Head `4944f1a29e` · +262/−5 in 8 Dateien · löst Shopify/ruby#1091
(tekknolagi: „Sure, that is fine“) · im Review

**Was falsch war.** Bei `"n#{i}"` oder `"#{klass} Update"` sendet ZJIT `to_s`. Der Interpreter (`vm_objtostring`) ruft
direkt `rb_fix_to_s`, das für 0 bis 9 einen gemeinsamen gefrorenen String liefert, und für ein Modul dessen
gespeicherten Namen. ZJIT legt in diesen Fällen also einen String mehr an.

```ruby
def label(i) = "n#{i}"
def update_name(klass) = "#{klass} Update"
100.times { label(5); update_name(String) }
p [allocs { label(5) }, allocs { label(42) }, allocs { update_name(String) }]
# Interpreter: [1, 2, 1], ZJIT master: [2, 2, 2], ZJIT PR: [1, 2, 1]
```

Wichtig für Thomas: Bei Integern spart das nur für 0 bis 9 ein Objekt. `label(42)` legt überall zwei Strings an.

**Was der PR ändert.** An einer Stelle, die nur eine Klasse gesehen hat und deren `to_s` noch das Original ist, ruft
ZJIT für einen Fixnum den neuen HIR-Befehl `FixnumToString` auf (ein `rb_fix_to_s` ohne eigenen Frame). Für ein Modul
ruft es `rb_mod_name` auf. Hat das Modul keinen Namen (anonym), liefert `rb_mod_name` nil. Dann springt der Code heraus
und kompiliert neu, und die letzte Version sendet wieder `to_s`.

```rust
// hir.rs, try_objtostring_cfunc
if profiled_type.is_fixnum() {
    let cme = unsafe { rb_callable_method_entry(klass, method_id) };
    if !unsafe { rb_zjit_cme_is_cfunc(cme, rb_int_to_s as *const c_void) } || !self.assume_no_singleton_classes(block, klass, state) {
        return None;
    }
    self.gen_patch_points_for_optimized_ccall(block, klass, method_id, cme, state);
    ...
    Some(self.push_insn(block, Insn::FixnumToString { val: recv, state }))
} else if ... klass.is_subclass_of(unsafe { rb_cModule }) == ClassRelationship::Subclass {
    ... Insn::CCall { cfunc: rb_mod_name as *const u8, ... }
    Some(self.push_insn(block, Insn::GuardType { val: name, guard_type: types::String, state, recompile: Some(Recompile) }))
}
```

**Warum das sicher ist.** Es ist abgesichert wie jeder optimierte C-Aufruf: Prüfung, dass `to_s` noch
`Integer#to_s` bzw. `Module#to_s` ist, und Patch-Points, die bei Umdefinition oder Refinement verwerfen. Das kann keine
Annotation in `cruby_methods` sein (wie #19587), weil ein normaler Aufruf `5.to_s` weiter einen neuen, veränderbaren
String liefern muss. Nur bei der Interpolation darf es der gemeinsame sein, genau wie im Interpreter.

**Wahrscheinlichste Frage.** Sie ist schon gestellt. k0kubun (2026-11-04 02:51): Die Struktur verwirrt ihn; `rb_int_to_s`
wirke wie ein Sonderfall und `rb_mod_to_s` wie der allgemeine Fall, obwohl beide nur zwei von vielen möglichen Fällen
sind. Er schlug eine einzige if-else-Kette vor. Unsere Antwort um 06:13 hat das umgesetzt (`4944f1a29e`) und angeboten, das
doppelte Nachschlagen in eine Hilfsfunktion zu ziehen, „if you prefer“. Kommt die Antwort „ja, Helper“: einfach machen,
nicht wieder fragen. Frühere Punkte von tekknolagi (rohe Strings in Tests, `fix_to_s` direkt ohne Frame, ein HIR-Name,
der nicht wie ein Methodenaufruf aussieht) sind erledigt und beantwortet.

**Stand.** Drei Punkte von tekknolagi (vier Inline-Kommentare) erledigt, k0kubuns Punkt erledigt. Wir warten auf k0kubun. CI grün, nur
Haiku läuft noch.

**Playbook.**
* Wirkung: Das Team hat zugestimmt (Shopify/ruby#1091), also greift die Ausnahme. Die Messung zählt Objekte, nicht Zeit:
  lobsters 4.270 → 0 `to_s`-Aufrufe pro Iteration, shipit 3.795 → 0.
* Ein Anliegen: ja, nur ZJIT. Das YJIT-Gegenstück #19665 ist geschlossen.
* Erklärbar: ja, mit dem Hinweis, dass es bei Integern nur 0 bis 9 betrifft.

**Vorschlag: behalten.**

### #19681: Register über C-Aufrufe finden, ohne quadratische Suche

[PR](https://github.com/ruby/ruby/pull/19681) · Head `dea97c3afa` · +116/−19 in 1 Datei · löst Shopify/ruby#1065
(tekknolagi: „go for it. Please also try and avoid allocating an interstitial Vec for every CCall.“) · kein Review

**Was falsch war.** Vor jedem C-Aufruf muss ZJIT die Register sichern, deren Werte über den Aufruf hinweg leben.
`handle_caller_saved_regs()` ging dafür bei jedem C-Aufruf alle Lebensintervalle durch. Der Aufwand ist also Zahl der
C-Aufrufe mal Zahl der Intervalle. In großen Methoden wird das Kompilieren dadurch sehr langsam.

```ruby
n = Integer(ARGV[0] || 4000)
src = +"def big(o)\n  s = 0\n"
n.times { src << "  s ^= o.hash\n" }
src << "  s\nend\n"
eval(src)
o = Object.new
3.times { big(o) }
# ruby --zjit --zjit-call-threshold=2 --zjit-stats big.rb 4000 | grep ^compile_time
# master etwa 3,6 s, PR etwa 1,6 s
```

**Was der PR ändert.** Vorab sammelt er die Positionen aller C-Aufrufe sortiert in einer Liste. Jeden Lebensbereich
jedes Registerintervalls ordnet er per binärer Suche (`partition_point`) diesen Positionen zu. Das Ergebnis kommt in eine
flache Tabelle: `covering_start` sagt, wo der Abschnitt eines C-Aufrufs in `covering_regs` beginnt. Jeder C-Aufruf
liest dann nur seinen Abschnitt; die Puffer werden wiederverwendet, es gibt also keinen Vec pro C-Aufruf.

```rust
// lir.rs
let first = ccall_positions.partition_point(|&pos| pos < range.from);
let last = ccall_positions.partition_point(|&pos| pos < range.to);
...
let position_idx = ccall_positions.binary_search(&insn_number).unwrap();
let covering = &covering_regs[covering_start[position_idx]..covering_start[position_idx + 1]];
survivors.clear();
survivors.extend(covering.iter().copied().filter(|&vreg_id| Some(vreg_id) != out_vreg_id));
```

**Warum das sicher ist.** Die Auswahl ist dieselbe wie vorher: `Interval::covers` heißt `from <= pos < to`, und
`partition_point` mit `pos < from` bzw. `pos < to` liefert genau die Positionen in diesem halboffenen Bereich. Die
Register aus der Stack-Map kommen wie vorher dazu, und die Liste wird nach VRegId sortiert. Damit bleibt die Reihenfolge
der Pushes gleich, und der erzeugte Code ist identisch. Normalisierte LIR-Dumps sind gleich, und ein Prüf-Build hat bei
jedem C-Aufruf durch railsbench, lobsters, shipit und btest alte und neue Liste verglichen.

**Wahrscheinlichste Frage.** „Ist der erzeugte Code wirklich gleich?“ Antwort wie oben. Zweite Frage: „Warum keine
Intervall-Aufteilung (splitting)?“ Antwort: Das ist eine Zwischenlösung, so steht es auch im PR. Splitting wäre ein
Umbau des Register-Allokators, und das Team hat nur um das Beheben des quadratischen Aufwands gebeten. Möglich ist
auch: „Was, wenn ein C-Aufruf keine `insn_id` hat (`unwrap_or(0)`)?“ Antwort: Dann bekommt er Position 0, wie
`insn_number` an dieser Stelle; der Prüf-Build hat keinen Unterschied gefunden. Diesen Punkt sollte Thomas vor einer
Antwort im Code nachlesen.

**Stand.** Kein Review. CI: `zjit-check` auf macOS ist rot, und das ist **unseres**: der wacklige Test
`test_send_proc_block_arg_to_block_param_callee` aus unserem gemergten #19484. #19699 repariert ihn. Wir warten auf
#19699; danach rebasen (einen Neustart der Jobs kann nur ein Maintainer auslösen). Bis dahin nicht pushen.

**Playbook.**
* Wirkung: Das Team hat darum gebeten (Shopify/ruby#1065), die Ausnahme greift. Auf railsbench, lobsters und shipit
  bewegt sich `compile_time` nur im Rauschen; bei der Methode mit 4.000 Aufrufen halbiert sich die Kompilierzeit.
* Ein Anliegen: ja, eine Datei.
* Erklärbar: ja. Die flache Tabelle (zwei Arrays, „start“ und „Inhalt“) sollte Thomas einmal selbst nachzeichnen.

**Vorschlag: behalten.**

### #19682: `super` aus einer Methode mit Block nicht mehr bei jedem Aufruf herausspringen

[PR](https://github.com/ruby/ruby/pull/19682) · Head `0442275697` · +90/−19 in 4 Dateien · zu Shopify/ruby#1100
(k0kubun: „It's free to take“) · approved von k0kubun

**Was falsch war.** Wird eine Methode mit Block aufgerufen und ruft sie `super` ohne eigenen Block auf, springt ZJIT bei
jedem Aufruf zurück in den Interpreter. Der spezialisierte `super`-Aufruf prüft, dass der Frame keinen Block hat, und
diese Prüfung kompiliert nie neu (`recompile: None`). Das ist ein dauerhafter Side-Exit. In Rails passiert das z. B. in
`ControllerRuntime#cleanup_view_runtime`.

```ruby
class A; def m = (block_given? ? yield : 0); end
class B < A; def m = super; end   # super reicht den Block des Aufrufs automatisch weiter
o = B.new
i = 0
while i < 20_000
  o.m { 1 }
  i += 1
end
# ruby --zjit --zjit-stats: exit_unhandled_block_arg master 19.971, PR 0
```

**Was der PR ändert.** Der Profiler merkt sich pro `invokesuper`-Stelle in einem `bool` (`super_saw_block`), ob der
Frame einen Block hatte. Solche Stellen nehmen beim Kompilieren den allgemeinen `super`-Weg, wie `super { }` schon heute.
Die Prüfung auf „kein Block“ kompiliert jetzt neu, falls doch erst nach dem Kompilieren ein Block auftaucht.

```rust
// profile.rs, profile_invokesuper
let passes_own_block = unsafe { rb_vm_ci_flag((*cd).ci) } & VM_CALL_ARGS_BLOCKARG != 0
    || !profiler.insn_opnd(1).as_iseq().is_null();
if !passes_own_block && !profiler.peek_at_block_handler().nil_p() {
    profile.entry_mut(profiler.insn_idx).super_saw_block = true;
}
// hir.rs
-                                recompile: None,
+                                recompile: Some(Recompile),
+                        if local_payload.profile.super_saw_block(frame_state_insn_idx) {
+                            ...
+                            self.set_dynamic_send_reason(insn_id, SuperCallWithBlock);
```

**Warum das sicher ist.** Der allgemeine `super`-Weg ist der, den der Interpreter auch nimmt; er reicht den Block
richtig weiter. Der neue `bool` sitzt im vorhandenen Padding von `ProfileEntry` und kostet keinen Speicher
(`zjit_alloc_bytes` gemessen, mit A/A).

**Wahrscheinlichste Frage.** Beide sind schon gestellt und beantwortet. k0kubun fragte nach dem Speicher: Die erste
Version mit einem `HashSet` kostete 99 KB auf railsbench und 244 KB auf lobsters; die `bool`-Version kostet nichts. Und
ob man `super(&block)` auslassen kann: ja, das ist umgesetzt, mit Test. Eine mögliche weitere Frage: „Warum nicht den
Block gleich durchreichen und voll spezialisieren?“ Antwort: Dafür bräuchte es eine neue Art Block-Handler, die auch
das Inlining kennen muss, und ruby-bench bewegt sich auch damit nicht.

**Stand.** Approved von k0kubun (2026-11-04 02:37: „I'd like to land a fix for the permanent exit“). Beide Punkte mit
`0442275697` umgesetzt und beantwortet. Dieser Commit kam nach dem Approve (wie von k0kubun erbeten); die neue Version
hat er noch nicht gesehen. CI grün. Wir warten auf den Merge, nichts zu tun.

**Playbook.**
* Wirkung: Der PR beseitigt einen dauerhaften Side-Exit, die Ausnahme greift. Exits pro Iteration: railsbench 2.052 → 0,
  lobsters 341 → 0, shipit 57 → 0.
* Ein Anliegen: ja.
* Erklärbar: ja.

**Vorschlag: behalten.**

### #19685 (Draft): jede ISEQ nur einmal pro GC markieren

[PR](https://github.com/ruby/ruby/pull/19685) · Draft · Head `aa82ba85e1` · +80/−14 in 3 Dateien

**Was falsch war.** Bei jeder Speicherbereinigung, auch den kleinen, geht `rb_zjit_root_mark` alle JIT-Frames durch und
markiert deren ISEQ. ZJIT legt einen JIT-Frame pro Aufrufstelle und Zustand an, also markiert es dieselben ISEQs immer
wieder (railsbench nach dem Aufwärmen: 38.118 Frames).

```ruby
2_000.times { |i| eval "def m#{i}(x) = x + 1; def c#{i}(x) = m#{i}(x) + m#{i}(x)" }
3.times { 2_000.times { |i| send(:"c#{i}", 1) } }
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
1_000.times { GC.start(full_mark: false) }
p Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
# ruby --zjit --zjit-call-threshold=1; nicht nachgemessen, der PR misst mit Callgrind auf ruby-bench
```

**Was der PR ändert.** Beim Anlegen eines JIT-Frames trägt ZJIT dessen ISEQ in eine Menge (`HashSet`) ein.
`rb_zjit_root_mark` markiert nur noch die Menge. Nach dem Kompaktieren wird die Menge mit `rb_gc_location` neu
aufgebaut, wie es `Invariants` für seine Tabellen tut.

```rust
// gc.rs, rb_zjit_root_mark
-    for &jit_frame in ZJITState::get_jit_frames().iter() {
-        unsafe { &*jit_frame }.mark();
+    for &iseq in ZJITState::get_jit_frame_iseqs().iter() {
+        unsafe { rb_gc_mark_movable(VALUE::from(iseq)); }
```

**Warum das sicher ist.** JIT-Frames werden nie freigegeben, und ihr ISEQ-Zeiger ändert sich nur beim Kompaktieren.
Darum enthält die Menge genau die ISEQs, die die alte Schleife markiert hat. Zwei Tests prüfen das nach einer kleinen GC
und nach dem Kompaktieren; ein dritter läuft unter `GC.stress` mit Auto-Kompaktierung.

**Wahrscheinlichste Frage.** „Wie viel Speicher kostet die Menge, und was bringt es auf `run_benchmarks.rb`?“ Antwort:
Beides ist nicht gemessen. Gemessen sind nur Callgrind-Instruktionen: `rb_zjit_root_mark` auf railsbench 28,5 M → 2,0 M
pro Iteration, die ganze Iteration −0,64 % (A/A 0,04 %).

**Stand.** Draft, auf Thomas' Wunsch nie zum Review gestellt. CI grün. Am selben Code arbeiten gerade XrXr (#19432, WIP,
ändert `jit_frame.rs` und `state.rs`) und rafaelfranca (#18949, JIT-Frame-Offsets).

**Playbook.**
* Wirkung: **nicht erfüllt.** Es gibt keinen `run_benchmarks.rb`-Effekt, nur Instruktionen, und das Team hat nicht
  darum gebeten.
* Speicher: Die Regel „`zjit_alloc_bytes` berichten“ ist für den neuen Dauerzustand nicht erfüllt.
* Maintainer-Arbeit am selben Code: XrXrs offener Umbau der JIT-Frames.
* Ein Anliegen und erklärbar: ja.

**Vorschlag: schließen.** Den Befund (Markieren pro Frame statt pro ISEQ) behalten wir in unseren Docs. Er geht nicht als
Issue raus, weil Performance-Leads nicht von sich aus Issues werden.

> Thanks to anyone who took a look. I'm closing this draft: it cuts the instructions spent on marking (measured with
> Callgrind), but I don't have a `run_benchmarks.rb` result for it beyond the noise.

### #19699: Test-Fix für den wackligen `test_send_proc_block_arg_to_block_param_callee`

[PR](https://github.com/ruby/ruby/pull/19699) · Head `642bcc8f5e` · +6/−4 in 1 Datei · kein Review

**Was falsch war.** Der Test stammt aus unserem gemergten #19484 und scheitert auf macOS gelegentlich. Der erste
`assert_snapshot!` in einem Testprozess startet `cargo metadata`, um das Workspace-Verzeichnis zu finden, wenn
`INSTA_WORKSPACE_ROOT` nicht gesetzt ist. Das Ende dieses Kindprozesses (SIGCHLD) setzt in Ruby einen
Unterbrechungswunsch. Ist der noch offen, wenn der zweite, eingebettete Lauf auf Unterbrechungen prüft, springt der
heraus (`exit_interrupt`). Ein einziger Side-Exit lässt `assert_inlines()` scheitern. Davon sind auch fremde PRs rot.

Ein Ruby-Beispiel gibt es hier nicht; es ist ein reiner Test-Fix. Belegt ist er mit einem A/B auf den macOS-Runnern von
GitHub (`macos-26`), 8 Shards: Test allein vorher 8 von 1.200 Läufen rot, nachher 0 von 1.200; in der ganzen Suite
vorher 5 von 32, nachher 0 von 32.

**Was der PR ändert.** Beide Programme laufen jetzt, bevor der erste Snapshot gemacht wird. Nur der Test ändert sich.

```rust
-    assert_snapshot!(assert_compiles(program), @"[true, true, 24, [nil, true, 4]]");
-    with_inlining(|| {
-        assert_snapshot!(assert_inlines(program), @"[true, true, 24, [nil, true, 4]]");
-    });
+    let sent_direct = assert_compiles(program);
+    let inlined = with_inlining(|| assert_inlines(program));
+    assert_snapshot!(sent_direct, @"[true, true, 24, [nil, true, 4]]");
+    assert_snapshot!(inlined, @"[true, true, 24, [nil, true, 4]]");
```

**Warum das sicher ist.** Der Test prüft dasselbe wie vorher, nur in anderer Reihenfolge.

**Wahrscheinlichste Frage.** „Warum nicht `INSTA_WORKSPACE_ROOT` im Makefile setzen? Dann startet insta nie `cargo
metadata`, und alle Tests sind geschützt.“ Antwort: Das ginge auch und schützt mehr. Wünscht der Reviewer das, setzen
wir es um, statt zu diskutieren (Regel: Änderung oder ein Blocker). Zweite mögliche Frage: „Braucht es den Kommentar?“
Ja, sonst stellt jemand die Reihenfolge wieder um.

**Stand.** Kein Review. CI grün (137 grün, 1 übersprungen).

**Playbook.**
* Wirkung: entfällt, es ist ein Test-Fix für unseren eigenen Test, der fremde CI rot macht. Das ist eine ausdrücklich
  erlaubte Ausnahme vom Öffnungsstopp (2026-11-04).
* Ein Anliegen: ja.
* Erklärbar: ja.

**Vorschlag: behalten.** #19681 wartet darauf.

---

## YJIT

YJIT ist laut XrXr und k0kubun im Wartungsmodus: nur noch Fehlerbehebungen. Thomas hat entschieden, dass unsere schon
offenen YJIT-PRs offen bleiben und die Maintainer über sie entscheiden. Drei der vier sind Korrektheit oder Diagnose;
nur #19487 ist Performance.

### #19487: `super` in Klassen- und Modulmethoden kompilieren

[PR](https://github.com/ruby/ruby/pull/19487) · Head `4f8f7fe7e7` · +83/−2 in 2 Dateien · approved von k0kubun
(2026-10-22)

**Was falsch war.** YJIT spezialisiert `super` nicht, wenn der Empfänger eine Singleton-Klasse hat, damit der
kompilierte Code den Empfänger nicht am Leben hält. Jede Klasse hat aber eine Singleton-Klasse, sobald sie
Klassenmethoden hat. Darum fällt jedes `super` aus einer Klassenmethode auf den langsamen Weg.

```ruby
class Base; def self.build = :base; end
class Child < Base; def self.build = super; end
i = 0
while i < 1_000_000
  Child.build
  i += 1
end
# ruby --yjit --yjit-stats | grep singleton_class: invokesuper singleton_class master 999.971, PR 0 (die Zeile fehlt dann)
```

**Was der PR ändert.** Er kompiliert `super` auch dann, wenn der Empfänger eine Klasse oder ein Modul ist, aber nur in
Methoden-ISEQs. Andere Objekte mit Singleton-Klasse und `super` in Blöcken bleiben beim alten Weg.

```rust
-    if VALUE(0) != unsafe { FL_TEST(comptime_recv.class_of(), VALUE(RUBY_FL_SINGLETON as usize)) } {
+    if VALUE(0) != unsafe { FL_TEST(comptime_recv.class_of(), VALUE(RUBY_FL_SINGLETON as usize)) }
+        && !(unsafe { rb_get_iseq_body_type(jit.iseq) } == ISEQ_TYPE_METHOD
+            && (unsafe { RB_TYPE_P(comptime_recv, RUBY_T_CLASS) }
+                || unsafe { RB_TYPE_P(comptime_recv, RUBY_T_MODULE) })) {
```

**Warum das sicher ist.** Normale Sends machen dieselbe Ausnahme für Klassen und Module schon heute. Klassen sind
meist ohnehin über eine Konstante erreichbar. Der kompilierte Code kann eine Klasse aber am Leben halten (z. B. ein
anonymes `Class.new`); normale Sends nehmen das für Klassen und Module schon heute in Kauf. Blöcke sind
ausgenommen, weil `instance_exec` einen Block an ein anderes `self` binden kann, ohne dass sich der Methodeneintrag
ändert; ein Test prüft genau das.

**Wahrscheinlichste Frage.** „Hält das Klassen unnötig im Speicher?“ Antwort: Nur Klassen und Module, wie bei normalen
Sends. k0kubun hat genau diesen Kompromiss approved („As a maintainer of `ERB::Util.html_escape`, I care about its
performance too“).

**Stand.** Approved seit 2026-10-22, nicht gemergt. Nach dem Approve ein Rebase (2026-10-23 08:04, ohne
Code-Änderung) und ein zusätzlicher Commit (20:23, „Keep rebound super blocks on the fallback path“). Der Commit kam
**nach** dem Approve und schließt eine Lücke der approvten Version: Sie hätte auch `super` in Blöcken spezialisiert,
die per `instance_exec` an eine andere Klasse gebunden werden. Kein Kommentar im PR erklärt diesen Commit, und
k0kubun hat die korrigierte Version noch nicht gesehen. Wahrscheinliche Frage dazu: „Was hat sich seit meinem Approve
geändert?“ Antwort: genau diese Einschränkung auf Methoden-ISEQs, mit dem Test `test_super_class_receiver_rebound_block`. CI grün. Ab 2026-11-05 erlaubt DECISIONS eine kurze
neutrale Notiz (14 Tage approved), einmal pro PR.

**Playbook.**
* Wirkung: nicht erfüllt. ruby-bench 0,990 (0,970 bis 1,009), also innerhalb des Rauschens.
* YJIT: ein Performance-PR im Wartungsmodus, aber vor der Regel geöffnet und approved.
* Ein Anliegen und erklärbar: ja.

**Vorschlag: behalten,** wegen des Approves und Thomas' Entscheidung zu den YJIT-PRs. Er ist der erste Kandidat, falls
das Limit noch Platz braucht. Dann:

> Thanks for the review and the approval. I'm closing this since YJIT is in maintenance mode and it doesn't move the
> headline benchmarks.

### #19492: dynamische Sends vor dem Aufruf zählen

[PR](https://github.com/ruby/ruby/pull/19492) · Head `1c6d753c71` · +35/−2 in 2 Dateien · approved von k0kubun
(2026-10-22: „sure.“)

**Was falsch war.** `--yjit-stats` zählt zu wenige dynamische Sends. Endet der Aufruf mit einer Exception, `throw` oder
einem `break` aus dem Block, wird `num_send_dynamic` übersprungen, weil das Hochzählen nach dem Aufruf steht. Das
Statistik-Werkzeug zeigt also falsche Zahlen.

```ruby
TARGET = Object.new
def TARGET.call = yield           # Singleton-Methode: YJIT ruft sie dynamisch auf
def op = (TARGET.call { raise "x" } rescue nil)
100.times { op }
RubyVM::YJIT.reset_stats!
10.times { op }
p RubyVM::YJIT.runtime_stats[:num_send_dynamic]
# ruby --yjit --yjit-stats=quiet: master 0, PR 10
```

**Was der PR ändert.** Er verschiebt das Hochzählen vor den Aufruf.

```rust
     jit_prepare_non_leaf_call(jit, asm);
+    gen_counter_incr(jit, asm, Counter::num_send_dynamic);
     let ret = vm_sendish(asm);
     ...
-    gen_counter_incr(jit, asm, Counter::num_send_dynamic);
```

**Warum das sicher ist.** `gen_counter_incr` erzeugt nur Code, wenn `--yjit-stats` an ist. Ohne Statistik ist der
erzeugte Code identisch.

**Wahrscheinlichste Frage.** „Kostet das Laufzeit?“ Antwort: Ohne `--yjit-stats` wird kein Code erzeugt; die
ruby-bench-Messung 0,999 (0,994 bis 1,004) zeigt nur das Rauschen.

**Stand.** Approved seit 2026-10-22, danach ein Rebase ohne Code-Änderung. CI: ein roter macOS-MMTk-Job vom
2026-10-23, nicht unseres (Runner-Problem, Log nicht mehr abrufbar). Ab 2026-11-05 ist die einmalige neutrale Notiz
erlaubt.

**Playbook.** Korrektheit der Diagnose, kein Performance-PR. Wartungsmodus erlaubt das. Ein Anliegen, sehr leicht zu
erklären.

**Vorschlag: behalten.**

### #19620: Backport eines YJIT-Korrektheitsfixes auf Ruby 3.4

[PR](https://github.com/ruby/ruby/pull/19620) · Basis `ruby_3_4` · Head `626b7bd20c` · +22/−0 in 3 Dateien · kein
Review

**Was falsch war.** Unter YJIT bekam ein Block, der über `enum_for` (eine IFUNC) mit expliziten Keywords aufgerufen
wird, die Keywords als positionelles Argument statt als Hash. Das ist ein falsches Ergebnis. Unser #19554 behebt es auf
master. k0kubun schrieb beim Approve von #19554: „we probably need to backport this as well“; der nach 4.0 (#19619) ist gemergt, dieser ist der nach 3.4.

```ruby
def values = yield([], key: 1)
p enum_for(:values).to_a
# ruby --yjit --yjit-call-threshold=1
#   Interpreter und master:  [[[], {key: 1}]]
#   ruby_3_4 (laut PR) und 4.0.9 (selbst ausgeführt): [[[], 1]]
```

4.0.9 zeigt den Fehler noch, weil es am 2026-10-23 erschien und der 4.0-Backport erst am 2026-10-30 gemergt wurde.

**Was der PR ändert.** Ein unverändertes `git cherry-pick -x` von 54d0988167: Kommt ein IFUNC-Block-Aufruf mit
expliziten Keywords, fällt YJIT auf den allgemeinen Weg zurück.

```rust
+        if flags & VM_CALL_KWARG != 0 {
+            gen_counter_incr(jit, asm, Counter::invokeblock_ifunc_kwarg);
+            return None;
+        }
```

**Warum das sicher ist.** Es ist nur ein weiterer Fall, in dem YJIT nicht kompiliert und den Interpreter-Weg nimmt.

**Wahrscheinlichste Frage.** „Warum rückportieren?“ Antwort: k0kubun hat beim Approve von #19554 einen Backport angeregt; es ist ein
falsches Ergebnis, kein Tempo. Zu den roten Jobs: Der i686-Job baut YJIT gar nicht, und der macOS-Fehler ist ein Timeout
im `debug`-Gem.

**Stand.** Kein Review seit 2026-10-30. 3.4-Backports entscheidet der Branch-Maintainer, nicht das JIT-Team; es kann
also dauern. CI: zwei rote Jobs, nicht unseres.

**Playbook.** Korrektheit mit Repro, YJIT-Korrektheit ist im Wartungsmodus ausdrücklich erlaubt, ein Anliegen,
trivial zu erklären.

**Vorschlag: behalten.**

### #19648: kein `Ractor::IsolationError` beim Kompilieren

[PR](https://github.com/ruby/ruby/pull/19648) · Head `cc33a7d70b` · +22/−3 in 5 Dateien · approved von k0kubun
(2026-11-02)

**Was falsch war.** YJIT liest beim Kompilieren das Objekt, an das eine Singleton-Klasse gebunden ist. Seit 17baadc072
(nur auf master, also neu in 4.1) wirft `rb_class_attached_object()` dabei einen Fehler, wenn das Objekt einem anderen
Ractor gehört und nicht teilbar ist, etwa der Block-Parameter-Proxy. Dann scheitert ein korrektes Programm in einem
Ractor nur, weil YJIT kompiliert.

```ruby
def call_block(&block) = block.call
p Ractor.new { call_block { :ok } }.value
# ruby --yjit-call-threshold=1
#   master: Ractor::IsolationError (can not get an unshareable attached object from another Ractor),
#           danach endet das Programm mit Ractor::RemoteError
#   Interpreter, 4.0.9 und PR: :ok
```

**Was der PR ändert.** Eine neue Funktion `rb_yjit_class_attached_object()` in `yjit.c` liest das Objekt ohne die
Ractor-Prüfung. YJIT benutzt sie an der einen Stelle in `jit_guard_known_klass`.

```c
VALUE
rb_yjit_class_attached_object(VALUE klass)
{
    RUBY_ASSERT(RCLASS_SINGLETON_P(klass));
    return RCLASS_ATTACHED_OBJECT(klass);
}
```

```rust
-            && sample_instance == rb_class_attached_object(known_klass)
+            && sample_instance == rb_yjit_class_attached_object(known_klass)
```

**Warum das sicher ist.** YJIT vergleicht das Objekt nur per Zeiger mit dem Beispielobjekt und gibt es nie an Ruby-Code
weiter. Die Ractor-Isolation wird also nicht umgangen.

**Wahrscheinlichste Frage.** Schon gestellt: k0kubun wollte die Funktion in `yjit.c` statt in `jit.c` und hat zusammen
mit dieser Bitte approved. Die Verschiebung kam danach mit `cc33a7d70b`, wie erbeten. Mögliche weitere Frage: „Warum ist `cruby_bindings.inc.rs` von Hand geändert?“ Antwort:
`make yjit-bindgen` scheiterte damals auf sauberem master aus einem anderen Grund; das steht im PR.

**Stand.** Approved, wir warten auf den Merge. CI: drei rote Jobs, nicht unseres; das haben wir am 2026-11-02 im PR mit
Links gezeigt.

**Playbook.** Korrektheit mit Repro und eine Regression in 4.1. Wartungsmodus erlaubt das. Ein Anliegen, leicht zu
erklären.

**Vorschlag: behalten.**

---

## Was Thomas jetzt entscheiden muss

1. **#19483, #19655 und #19685 schließen**, mit den Kommentaren oben. Danach sind 10 offen, genau das Limit.
2. **Am 2026-11-05** ist für #19487 und #19492 je eine neutrale Notiz erlaubt (14 Tage approved). Das ist optional.
3. **Wenn #19699 gemergt ist:** #19681 rebasen, damit seine CI grün wird.
4. **#19670 vor dem Review:** entscheiden, ob der Fix vollständig werden soll (immer in den frischen Hash mergen),
   oder bei der Frage nachziehen.
