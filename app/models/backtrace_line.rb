class BacktraceLine < ActiveRecord::Base
  IN_APP_PATH = %r{^\[PROJECT_ROOT\](?!(\/vendor))/?}
  GEMS_PATH   = %r{\[GEM_ROOT\]\/gems\/([^\/]+)}

#  field :number, :type => Integer
#  field :file
#  field :method

#  embedded_in :backtrace
  belongs_to :backtrace

  scope :in_app, where(:file => IN_APP_PATH)

  delegate :app, :to => :backtrace

  def to_s
    "#{file}:#{number}"
  end

  def in_app?
    !!(file =~ IN_APP_PATH)
  end

  def path
    File.dirname(file).gsub(/^\.$/, '') + "/"
  end

  def file_relative
    file.to_s.sub(IN_APP_PATH, '')
  end

  def file_name
    File.basename file
  end

  def decorated_path
    path.sub(BacktraceLine::IN_APP_PATH, '').
      sub(BacktraceLine::GEMS_PATH, "<strong>\\1</strong>")
  end

end

