class IssueTracker < ActiveRecord::Base

  include HashHelper
  include Rails.application.routes.url_helpers
  default_url_options[:host] = ActionMailer::Base.default_url_options[:host]

#  embedded_in :app, :inverse_of => :issue_tracker
  belongs_to :app, inverse_of: :issue_tracker
#  field :project_id, :type => String
#  field :alt_project_id, :type => String # Specify an alternative project id. e.g. for viewing files
#  field :api_token, :type => String
#  field :account, :type => String
#  field :username, :type => String
#  field :password, :type => String
#  field :ticket_properties, :type => String
#  field :subdomain, :type => String

  validate :check_params

  # Subclasses are responsible for overwriting this method.
  # FIXME: problem with AR & has_one, try resolve this through patch build_issue_tracker
  def check_params
    return true if type.blank?
    sti = type.constantize.new(self.attributes)
    sti.valid?
    sti.errors[:base].each {|msg| self.errors.add :base, msg}
  end

  def issue_title(problem)
    "[#{ problem.environment }][#{ problem.where }] #{problem.message.to_s.truncate(100)}"
  end

  # Allows us to set the issue tracker class from a single form.

  def url; nil; end

  # Retrieve tracker label from either class or instance.
  Label = ''
  def self.label; self::Label; end
  def label; self.class.label; end

  def configured?
    project_id.present?
  end
end

