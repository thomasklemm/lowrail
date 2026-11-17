# Upper bound only (not exact): memoize alternative_subjects per subject class.
CanCan::Ability.prepend(Module.new do
  def alternative_subjects(subject)
    k = subject.is_a?(Module) ? subject : subject.class
    ((@__alt ||= {})[k] ||= super)
  end
end)
