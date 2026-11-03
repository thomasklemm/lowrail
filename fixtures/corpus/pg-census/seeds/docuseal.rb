# Docuseal census data: what /setup creates (account, admin, app URL and
# e-sign certificates), plus templates and submissions built like the API does.
srand(42)
account = Account.create!(name: "Census Co", timezone: "UTC", locale: "en-US")
user = account.users.create!(first_name: "Ada", last_name: "Census", email: "ada@census.test", password: "census-password-123", role: User::ADMIN_ROLE)
account.encrypted_configs.create!([
  { key: EncryptedConfig::APP_URL_KEY, value: "https://localhost" },
  { key: EncryptedConfig::ESIGN_CERTS_KEY, value: GenerateCertificate.call.transform_values(&:to_pem) }
])
account.account_configs.create!(key: :fulltext_search, value: true) if SearchEntry.table_exists?
types = %w[text date checkbox signature number select initials phone]
6.times do |t|
  submitters = Array.new(2) { |i| { "name" => "#{%w[First Second][i]} Party", "uuid" => SecureRandom.uuid } }
  fields = submitters.flat_map do |s|
    types.map.with_index do |type, k|
      { "uuid" => SecureRandom.uuid, "submitter_uuid" => s["uuid"], "name" => "#{type.capitalize} #{k}", "type" => type,
        "required" => k.even?, "preferences" => {}, "areas" => [] }.tap { _1["options"] = [{ "value" => "A", "uuid" => SecureRandom.uuid }, { "value" => "B", "uuid" => SecureRandom.uuid }] if type == "select" }
    end
  end
  template = Template.create!(account: account, author: user, name: "Census agreement #{t + 1}", submitters: submitters,
    fields: fields, schema: [])
  4.times do |n|
    submission = template.submissions.create!(account: account, created_by_user: user, source: :api, submitters_order: :random,
      template_submitters: template.submitters, template_fields: template.fields, template_schema: template.schema)
    template.submitters.each_with_index do |ts, i|
      submission.submitters.create!(account: account, uuid: ts["uuid"], email: "signer#{t}#{n}#{i}@census.test",
        name: "Signer #{t}-#{n}-#{i}", values: {}, completed_at: (n.even? ? Time.current : nil))
    end
  end
end
puts({ templates: Template.count, submissions: Submission.count, submitters: Submitter.count }.inspect)
