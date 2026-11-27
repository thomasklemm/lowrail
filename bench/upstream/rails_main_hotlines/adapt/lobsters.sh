# Gem upgrades that make the suite pass on main (gem-side fixes already released), applied to both trees.
UPGRADE="rspec-rails"
# activerecord-typedstore master 263050a196 (#114, 2026-10-27, unreleased; 1.6.0 is from 2024): no Active Record
# reader for store accessors, which main's slot readers (rails/rails#59141) refuse to define.
EXTRA='gem "activerecord-typedstore", github: "byroot/activerecord-typedstore", ref: "263050a19621d76c140042601f72f31d47cedfba"'
