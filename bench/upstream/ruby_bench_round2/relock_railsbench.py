"""Move railsbench's Gemfile.lock to Rails 8.1.4.1 by copying the spec blocks and
checksums that `bundle lock --update` produced for lobsters (same Rails gems,
same platform-independent sanitizer chain). The JRuby-only entries stay as on
main; only nokogiri-java moves with the ruby variant."""
import re, sys
rb, lob, java_sha = sys.argv[1], sys.argv[2], sys.argv[3]
names = {"actionmailbox", "actionmailer", "actionpack", "actiontext", "actionview", "activejob",
         "activemodel", "activerecord", "activestorage", "activesupport", "railties",
         "loofah", "rails-html-sanitizer"}

def blocks(text):
    out, cur = {}, None
    for line in text.split("\n"):
        m = re.match(r"^    (\S+) \(([^)]+)\)$", line)
        if m:
            cur = (m[1], m[2]); out[cur] = [line]
        elif cur and line.startswith("      "):
            out[cur].append(line)
        else:
            cur = None
    return out

lt = open(lob).read()
lb = blocks(lt)
lsum = dict(re.findall(r"^  (\S+ \([^)]+\)) (sha256=\w+)$", lt, re.M))
src = {n: b for (n, v), b in lb.items() if n in names and "-" not in v}
src["nokogiri"] = lb[("nokogiri", "1.19.7")]

lines, out, i = open(rb).read().split("\n"), [], 0
while i < len(lines):
    line = lines[i]
    m = re.match(r"^    (\S+) \(([^)]+)\)$", line)
    if m and (m[1] in src or m[1] == "nokogiri"):
        j = i + 1
        while j < len(lines) and lines[j].startswith("      "):
            j += 1
        n, v = m[1], m[2]
        if n == "nokogiri" and v.endswith("-java"):
            out += ["    nokogiri (1.19.7-java)", "      racc (~> 1.4)"]
        elif n == "nokogiri" and v.endswith("-x86_64-linux-gnu"):
            out += ["    nokogiri (1.19.7-x86_64-linux-gnu)", "      racc (~> 1.4)"]
        else:
            out += src[n]
        i = j
        continue
    m = re.match(r"^  (\S+) \(([^)]+)\) sha256=\w+$", line)
    if m and (m[1] in src or m[1] == "nokogiri"):
        n, v = m[1], m[2]
        if n == "nokogiri":
            key = "nokogiri (1.19.7" + v[len("1.18.9"):] + ")"
            sha = "sha256=" + java_sha if v.endswith("-java") else lsum.get(key)
            if sha is None:  # x86_64-linux-gnu variant: lobsters has none
                sha = "sha256=25865ccb462f714e712fdf8906fde07849cb6704a808e3d629d75baa5af5dd3b"
            out.append(f"  {key} {sha}")
        else:
            key = f"{n} ({src[n][0].split('(')[1]}"
            out.append(f"  {key} {lsum[key]}")
        i += 1
        continue
    out.append(line)
    i += 1
open(rb, "w").write("\n".join(out))
