class Job < ActiveRecord::Base
  extend FriendlyId
  enum status: [:pending, :published, :reproved, :removed]

  scope :visible, -> { where(status: Job.statuses[:published]).order(updated_at: :desc) }
  scope :awaiting_approval, -> { where(status: Job.statuses[:pending]) }

  friendly_id :unique_slug, :use => [:slugged, :finders]
  searchkick language: "brazilian"

  paginates_per 10
  has_secure_token

  belongs_to :job_type
  belongs_to :category
  belongs_to :company

  validates :title, presence: true
  validates :job_type, presence: true
  validates :category, presence: true
  validates :company, presence: true
  validates :author, presence: true
  validates :author_email, presence: true
  validates :link, :format => URI::regexp(%w(http https)), allow_blank: true

  after_create :send_mail_to_admins

  def ad
    "Startup: <strong>#{self.company.title}</strong>" +
    "<br/>Área: <strong>#{self.category.title}</strong>" +
    "<br/>Regime de contratação: <strong>#{self.job_type.title}</strong>"
  end

  def should_generate_new_friendly_id?
    title_changed?
  end

  def unique_slug
    "#{self.title}-#{self.company.title if self.company.present?}"
  end

  def slug_candidates
    [
      :unique_slug
    ]
  end

  def search_data
    {
      title: title,
      description: description,
      company_name: company.title,
      job_type_name: job_type.title,
      category_name: category.title,
      location: location,
      status: status
    }
  end

  def remove(email, token)
    if self.author_email == email && self.token == token
      self.removed!
    else
      false
    end
  end

  def self.query(query, page)
    if query == "*"
      Job.visible.page(page)
    else
      self.search query,
        where: {status: "published"},
        fields: ['title^10', 'description', 'location', 'company_name', 'job_type_name', 'category_name'],
        page: page,
        per_page: 10
    end
  end

  def send_mail_to_admins
    JobMailer.job_created(self).deliver_later
  end
end
