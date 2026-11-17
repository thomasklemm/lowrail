# Measurement patch: same positions (multiset), found by walking the index keys instead of 86 Hash lookups.
# Same calls to alternative_subjects (ancestors, descendants); keys compared with == instead of hash/eql?.
CanCan::Ability.prepend(Module.new do
  private def possible_relevant_rules(subject)
    return rules if subject.is_a?(Hash)
    candidates = [subject, *alternative_subjects(subject)]
    positions = []
    @rules_index.each { |key, pos| candidates.count(key).times { positions.concat(pos) } }
    positions.sort!
    positions.map { |i| @rules[i] }
  end
end)
