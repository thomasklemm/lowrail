# frozen_string_literal: true

class EqWriter < ActiveRecord::Base
  has_many :posts, class_name: "EqPost", foreign_key: :writer_id, inverse_of: :writer
  has_many :preferred_posts, -> { where(published: true).order(:title).limit(2) }, class_name: "EqPost", foreign_key: :writer_id
  has_one :first_post, -> { order(:id) }, class_name: "EqPost", foreign_key: :writer_id
  has_many :empty_posts, -> { where(id: nil) }, class_name: "EqPost", foreign_key: :writer_id
  has_many :zero_posts, -> { limit(0) }, class_name: "EqPost", foreign_key: :writer_id
  has_many :selected_posts, -> { select(:id, :writer_id).order(id: :desc) }, class_name: "EqPost", foreign_key: :writer_id
  has_many :preloaded_posts, -> { where(published: false).preload(:notes) }, class_name: "EqPost", foreign_key: :writer_id
  has_many :live_posts, -> { where(status: :live) }, class_name: "EqPost", foreign_key: :writer_id
  has_many :same_posts, class_name: "EqPost", foreign_key: :writer_id
  has_many :writer_notes, through: :posts, source: :notes
  has_many :assets, as: :notable, class_name: "EqAsset"
end

class EqFoldedString < ActiveRecord::Type::String
  def serialize(value) = super(value&.downcase)
end

class EqPost < ActiveRecord::Base
  belongs_to :writer, class_name: "EqWriter", inverse_of: :posts
  has_many :notes, class_name: "EqNote", foreign_key: :post_id, inverse_of: :post
  has_many :assets, as: :notable, class_name: "EqAsset"
  enum :status, { draft: 0, live: 1 }
  serialize :settings, coder: JSON
  attribute :slug, EqFoldedString.new
  scope :published_first, -> { where(published: true).order(id: :desc) }
end

class EqDefaultPost < EqPost
  self.table_name = "eq_posts"
  default_scope { where(published: true) }
end

class EqNote < ActiveRecord::Base
  belongs_to :post, class_name: "EqPost", inverse_of: :notes
end

class EqAsset < ActiveRecord::Base
  belongs_to :notable, polymorphic: true
end

class EqSpecialAsset < EqAsset
end
