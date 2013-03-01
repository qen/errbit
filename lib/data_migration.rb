require 'rubygems'
require 'mongo'
require "activerecord-import/base"
ActiveRecord::Import.require_adapter('postgresql')

include Mongo

class DataMigration
  attr_reader :db, :mongo_client, :user_mapping

  def initialize(config)
    config = config.with_indifferent_access
    config[:host] ||= 'localhost'
    config[:port] ||= 27017
    @cursor_options = {:timeout => false, :batch_size => 100, :sort => ["_id", "asc"]}
    @mongo_client = MongoClient.new(config[:host], config[:port])
    @db = @mongo_client[config[:database].to_s]
  end

  def start
    Notice.observers.disable :all
    Deploy.observers.disable :all
    copy_users
    copy_apps
  end

  def copy_users
    counter = 0
    total = db[:users].count
    log "Start copy users, total: #{total}"

    @user_mapping = {}
    db[:users].find({}, @cursor_options) do |cursor|
      cursor.each do |old_user|
        log "  copying user ##{counter += 1} of #{total} with id #{old_user['_id']}"

        user = copy_user(old_user)
        @user_mapping[old_user["_id"]] = user.id
      end
    end
  end

  def copy_apps
    counter = 0
    total = db[:apps].count
    log "Start copy apps, total: #{total}"

    db[:apps].find({}, @cursor_options) do |cursor|
      cursor.each do |old_app|
        log "  copying app ##{counter += 1} of #{total} with id #{old_app['_id']}"

        app = copy_app(old_app)
        copy_watchers(old_app, app)
        copy_deploys(old_app, app)
        copy_problems(old_app, app)
      end
    end
  end

  def copy_watchers(old_app, app)
    if old_app["watchers"]
      counter = 0
      total = old_app["watchers"].count
      log "  Start copy watchers, total: #{total}"

      watchers = []
      old_app["watchers"].each do |watcher|
        log "    copying watcher ##{counter += 1} of #{total} with id #{watcher['_id']}"

        watchers << copy_watcher(app, watcher)
      end
      Watcher.import watchers
    end
  end

  def copy_watcher(app, old_watcher)
    watcher = app.watchers.new
    watcher.email = old_watcher["email"]
    if old_watcher["user_id"]
      user_id = @user_mapping[old_watcher["user_id"]]
      watcher.user = User.find(user_id)
    end
    watcher
  end

  def copy_deploys(old_app, app)
    if old_app["deploys"]
      counter = 0
      total = old_app["deploys"].count
      log "  Start copy deploys, total: #{total}"

      deploys = []
      old_app["deploys"].each do |deploy|
        log "    copying deploy ##{counter += 1} of #{total} with id #{deploy['_id']}"

        deploys << copy_deploy(app, deploy)
        if(deploys.count > 100)
          Deploy.import deploys
          deploys = []
        end
      end
      Deploy.import deploys
    end
  end

  def copy_deploy(app, old_deploy)
    columns = Deploy.columns.map(&:name)
    deploy = app.deploys.new
    copy_columns(columns, old_deploy, deploy)
    deploy
  end

  def copy_problems(old_app, app)
    counter = 0
    total = db[:problems].find("app_id" => old_app["_id"]).count
    log "  Start copy problems, total: #{total}"

    db[:problems].find({"app_id" => old_app["_id"]}, @cursor_options) do |cursor|
      cursor.each do |old_problem|
        log "    copying problem ##{counter += 1} of #{total} with id #{old_problem['_id']}"

        problem = copy_problem(app, old_problem)
        copy_comments(problem, old_problem)
        copy_errs(problem, old_problem)

        # return resolve flag
        problem.resolved = old_problem["resolved"]
        problem.resolved_at = old_problem["resolved_at"]
        problem.save
      end
    end
  end

  def copy_comments(problem, old_problem)
    counter = 0
    total = db[:comments].find("err_id" => old_problem["_id"]).count
    log "    Start copy comments, total: #{total}"

    db[:comments].find({"err_id" => old_problem["_id"]}, @cursor_options) do |cursor|
      cursor.each do |old_comment|
        log "      copying comment ##{counter += 1} of #{total} with id #{old_comment['_id']}"

        copy_comment(problem, old_comment)
      end
    end
  end

  def copy_errs(problem, old_problem)
    counter = 0
    total = db[:errs].find("problem_id" => old_problem["_id"]).count
    log "    Start copy errs, total: #{total}"

    db[:errs].find({"problem_id" => old_problem["_id"]}, @cursor_options) do |cursor|
      cursor.each do |old_err|
        log "    copying err ##{counter += 1} of #{total} with id #{old_err['_id']}"

        err = copy_err(problem, old_err)
        copy_notices(err, old_err)
      end
    end
  end

  def copy_err(problem, old_err)
    err = problem.errs.new
    columns = Err.columns.map(&:name).reject {|c| c.in? ["problem_id"]}
    copy_columns(columns, old_err, err)

    err.save!
    err
  end


  def copy_notices(err, old_err)
    counter = 0
    total = db[:notices].find("err_id" => old_err["_id"]).count
    log "      Start copy notices, total: #{total}"

    notices = []
    db[:notices].find({"err_id" => old_err["_id"]}, @cursor_options) do |cursor|
      cursor.each do |old_notice|
        log "        copying notice ##{counter += 1} of #{total} with id #{old_notice['_id']}"

        notices << copy_notice(err, old_notice)
        if(notices.count > 100)
          Notice.import notices
          notices = []
        end
      end
    end
    Notice.import notices
  end

  def copy_notice(err, old_notice)
    notice = err.notices.new
    columns = Notice.columns.map(&:name).reject{|c| c.in?(["err_id", "backtrace_id"])}
    copy_columns(columns, old_notice, notice)

    notice.backtrace = copy_backtrace(notice, old_notice)

    notice
  end

  def copy_backtrace(notice, old_notice)
    old_backtrace = db[:backtraces].find({"_id" => old_notice["backtrace_id"]}).first
    backtrace = notice.build_backtrace
    columns = Backtrace.columns.map(&:name)
    copy_columns(columns, old_backtrace, backtrace)
    backtrace.save!
    copy_backtrace_lines(backtrace, old_backtrace)

    backtrace
  end

  private
    def copy_user(old_user)
      columns = User.columns.map(&:name)
      user = User.new
      copy_columns(columns, old_user, user)
      # disable validation, cause devise require password. Try create "type" without password validation
      user.save(:validate => false)
      user
    end

    def copy_app(old_app)
      app_columns = App.columns.map(&:name)
      app = App.new
      copy_columns(app_columns, old_app, app)
      app.save!

      copy_issue_tracker(app, old_app)
      copy_notification_service(app, old_app)

      app
    end

    def copy_issue_tracker(app, old_app)
      return unless old_app["issue_tracker"]
      issue_tracker = app.build_issue_tracker
      columns = IssueTracker.columns.map(&:name)
      copy_columns(columns, old_app["issue_tracker"], issue_tracker)
      app.issue_tracker.type = normalize_issue_tracker_classname(old_app["issue_tracker"]["_type"])

      # disable validate because have problem with different schemas in db
      issue_tracker.save(:validate => false)
    end

    def copy_notification_service(app, old_app)
      return unless old_app["notification_service"]
      notification_service = app.build_notification_service
      columns = NotificationService.columns.map(&:name)
      copy_columns(columns, old_app["notification_service"], notification_service)
      app.notification_service.type = normalize_notification_service_classname(old_app["notification_service"]["_type"])

      # disable validate because have problem with different schemas in db
      notification_service.save(:validate => false)
    end

    def normalize_issue_tracker_classname(name)
      return nil unless name[/IssueTrackers?::/]
      "IssueTrackers::#{name.demodulize}"
    end

    def normalize_notification_service_classname(name)
      return nil unless name[/NotificationServices?::/]
      "NotificationService::#{name.demodulize}"
    end

    def copy_comment(problem, old_comment)
      comment = problem.comments.new
      columns = ["body", "created_at", "updated_at"]
      copy_columns(columns, old_comment, comment)

      user_id = @user_mapping[old_comment["user_id"]]
      comment.user = User.find(user_id) if user_id

      comment.save!
      comment
    end

    def copy_problem(app, old_problem)
      problem = Problem.new
      columns = Problem.columns.map(&:name).reject{|c| c.in?(["notices_count", "comments_count"])}
      copy_columns(columns, old_problem, problem)
      problem.app = app
      problem.save!
      problem
    end

    def copy_backtrace_lines(backtrace, old_backtrace)
      if old_backtrace["lines"]
        lines = []
        old_backtrace["lines"].each do |old_line|
          lines << copy_backtrace_line(backtrace, old_line)
        end
        BacktraceLine.import lines
      end
    end

    def copy_backtrace_line(backtrace, old_line)
      line = backtrace.lines.new
      columns = BacktraceLine.columns.map(&:name)
      copy_columns(columns, old_line, line)

      line
    end

    def copy_columns(columns, copy_from, copy_to)
      copy_from = copy_from.with_indifferent_access

      columns.each do |column|
        copy_to.send("#{column}=", copy_from[column]) if copy_from.has_key? column
      end

      copy_to
    end

    def log(message)
      puts "[#{Time.current.to_s(:db)}] #{message}"
    end

end

