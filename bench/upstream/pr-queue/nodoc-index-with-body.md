### Mark Array#index_with as :nodoc:

Follow-up to #59555, per https://github.com/rails/rails/pull/59555#discussion_r4483889444: `Array#index_with` is a specialization of `Enumerable#index_with`, so it gets `# :nodoc:` instead of a comment that ends up in the API docs, like `Array#compact_blank`.
