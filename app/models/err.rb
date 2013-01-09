# Represents a set of Notices which can be automatically
# determined to refer to the same Error (Errbit groups
# notices into errs by a notice's fingerprint.)

class Err < ActiveRecord::Base

#  field :error_class, :default => "UnknownError"
#  field :component
#  field :action
#  field :environment, :default => "unknown"
#  field :fingerprint

  belongs_to :problem, inverse_of: :errs
#  index :problem_id
#  index :error_class
#  index :fingerprint

  has_many :notices, :inverse_of => :err, :dependent => :destroy

  delegate :app, :resolved?, :to => :problem
  after_initialize :default_values

  def default_values
    if self.new_record?
      self.error_class ||= "UnknownError"
      self.environment ||= "unknown"
    end
  end
end

