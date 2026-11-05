FIX: Scope Category#category_channels to the category's channels

`Category#category_channels` is declared with [`foreign_key: %i[chatable_id chatable_type]`](https://github.com/discourse/discourse/blob/de34d8ac4f9d31eea2d4c3e2de397f60e239ee88/plugins/chat/lib/chat/category_extension.rb#L14-L18), which maps the category's one-column primary key onto two columns. On Rails 8.1 the association quietly queries `chatable_id IS NULL AND chatable_type IS NULL`, so [`has_chat_channels`](https://github.com/discourse/discourse/blob/de34d8ac4f9d31eea2d4c3e2de397f60e239ee88/plugins/chat/plugin.rb#L419-L423) in the category serializer is always false. On Rails main (since rails/rails#59120) the same declaration raises `ArgumentError: Key mappings must have the same number of columns` on every read, so with chat enabled every category save fails and `db:migrate` can't seed the Uncategorized category.

This declares it with `as: :chatable`, like `has_one :category_channel` above it. Nothing in the frontend reads `has_chat_channels`, so on 8.1 the only change is that category JSON, MessageBus and webhook payloads report `true` for categories with channels; the query count stays the same. I dropped `dependent: :destroy` from the `has_many`, so deleting a category still destroys only the one channel `has_one :category_channel` destroys today. Keeping it would now also destroy the category's other channels, including ones with messages.

The new spec fails without the fix. The chat plugin's specs (without system specs) pass on Rails 8.1.4.1 and on Rails main; on main without the fix, 2,718 of their 3,220 examples fail.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
