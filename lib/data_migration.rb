require 'rubygems'
require 'mongo'
require "activerecord-import/base"

include Mongo
ActiveRecord::Import.require_adapter('postgresql')

module DataMigration
  def self.start(*args)
    worker = Worker.new(*args)
    worker.start
  end

  class DBPrepareMigration < ActiveRecord::Migration
    def self.up
      add_column :users, :remote_id, :string
      add_column :apps, :remote_id, :string
      add_column :backtraces, :remote_id, :string
      add_column :errs, :remote_id, :string
      add_column :problems, :remote_id, :string

      remove_index :backtraces, :column => :fingerprint
      remove_index :backtrace_lines, :column => :backtrace_id
      remove_index :comments, :column => :user_id
      remove_index :comments, :column => :problem_id
      remove_index :deploys, :column => :app_id
      remove_index :errs, :column => :problem_id
      remove_index :errs, :column => :error_class
      remove_index :errs, :column => :fingerprint
      remove_index :issue_trackers, :column => :app_id
      remove_index :notices, :column => [:err_id, :created_at, :id]
      remove_index :notices, :column => :backtrace_id
      remove_index :notification_services, :column => :app_id
      remove_index :problems, :column => :app_id
      remove_index :problems, :column => :app_name
      remove_index :problems, :column => :message
      remove_index :problems, :column => :last_notice_at
      remove_index :problems, :column => :first_notice_at
      remove_index :problems, :column => :resolved_at
      remove_index :problems, :column => :notices_count
      remove_index :problems, :column => :comments_count
      remove_index :watchers, :column => :app_id
      remove_index :watchers, :column => :user_id
    end

    def self.down
      remove_column :users, :remote_id
      remove_column :apps, :remote_id
      remove_column :backtraces, :remote_id
      remove_column :errs, :remote_id
      remove_column :problems, :remote_id

      add_index :backtraces, :fingerprint
      add_index :backtrace_lines, :backtrace_id
      add_index :comments, :user_id
      add_index :comments, :problem_id
      add_index :deploys, :app_id
      add_index :errs, :problem_id
      add_index :errs, :error_class
      add_index :errs, :fingerprint
      add_index :issue_trackers, :app_id
      add_index :notices, [:err_id, :created_at, :id]
      add_index :notices, :backtrace_id
      add_index :notification_services, :app_id
      add_index :problems, :app_id
      add_index :problems, :app_name
      add_index :problems, :message
      add_index :problems, :last_notice_at
      add_index :problems, :first_notice_at
      add_index :problems, :resolved_at
      add_index :problems, :notices_count
      add_index :problems, :comments_count
      add_index :watchers, :app_id
      add_index :watchers, :user_id
    end
  end

  class Worker
    USER_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "github_login" => "github_login",
      "github_oauth_token" => "github_oauth_token",
      "name" => "name",
      "username" => "username",
      "admin" => "admin",
      "per_page" => "per_page",
      "time_zone" => "time_zone",
      "created_at" => "created_at",
      "updated_at" => "updated_at",
      "email" => "email",
      "encrypted_password" => "encrypted_password",
      "reset_password_token" => "reset_password_token",
      "remember_token" => "remember_token",
      "remember_created_at" => "remember_created_at",
      "sign_in_count" => "sign_in_count",
      "current_sign_in_at" => "current_sign_in_at",
      "last_sign_in_at" => "last_sign_in_at",
      "current_sign_in_ip" => "current_sign_in_ip",
      "last_sign_in_ip" => "last_sign_in_ip",
      "authentication_token" => "authentication_token"
    }

    APP_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "name" => "name",
      "api_key" => "api_key",
      "github_repo" => "github_repo",
      "bitbucket_repo" => "bitbucket_repo",
      "repository_branch" => "repository_branch",
      "resolve_errs_on_deploy" => "resolve_errs_on_deploy",
      "notify_all_users" => "notify_all_users",
      "notify_on_errs" => "notify_on_errs",
      "notify_on_deploys" => "notify_on_deploys",
      "email_at_notices" => "email_at_notices",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    DEPLOY_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "username" => "username",
      "repository" => "repository",
      "environment" => "environment",
      "revision" => "revision",
      "message" => "message",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    PROBLEM_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "last_notice_at" => "last_notice_at",
      "first_notice_at" => "first_notice_at",
      "last_deploy_at" => "last_deploy_at",
      "resolved" => "resolved",
      "resolved_at" => "resolved_at",
      "issue_link" => "issue_link",
      "issue_type" => "issue_type",
      "app_name" => "app_name",
      "message" => "message",
      "environment" => "environment",
      "error_class" => "error_class",
      "where" => "where",
      "user_agents" => "user_agents",
      "messages" => "messages",
      "hosts" => "hosts",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    ERR_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "error_class" => "error_class",
      "component" => "component",
      "action" => "action",
      "environment" => "environment",
      "fingerprint" => "fingerprint",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    BACKTRACE_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "fingerprint" => "fingerprint",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    BACKTRACE_LINE_FIELDS_MAPPING = {
      "number" => "number",
      "file" => "file",
      "method" => "method",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    NOTICE_FIELDS_MAPPING = {
      lambda{|v| v["_id"].to_s} => "remote_id",
      "message" => "message",
      "server_environment" => "server_environment",
      "request" => "request",
      "notifier" => "notifier",
      "user_attributes" => "user_attributes",
      "framework" => "framework",
      "current_user" => "current_user",
      "error_class" => "error_class",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    ISSUE_TRACKER_FIELDS_MAPPING = {
      "project_id" => "project_id",
      "alt_project_id" => "alt_project_id",
      "api_token" => "api_token",
      "account" => "account",
      "username" => "username",
      "password" => "password",
      "ticket_properties" => "ticket_properties",
      "subdomain" => "subdomain",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    NOTIFICATION_SERVICE_FIELDS_MAPPING = {
      "room_id" => "room_id",
      "user_id" => "user_id",
      "service_url" => "service_url",
      "service" => "service",
      "api_token" => "api_token",
      "subdomain" => "subdomain",
      "sender_name" => "sender_name",
      "created_at" => "created_at",
      "updated_at" => "updated_at"
    }

    attr_reader :db, :mongo_client

    def initialize(config)
      config = config.with_indifferent_access
      config[:host] ||= 'localhost'
      config[:port] ||= 27017
      @mongo_client = MongoClient.new(config[:host], config[:port])
      @db = @mongo_client[config[:database].to_s]
    end

    def start
      db_prepare
      app_prepare

      copy_users
      copy_apps
      copy_problems
      copy_comments
      copy_errs
      copy_backtraces
      copy_notices

      db_clean
    end

    def app_prepare
      Notice.observers.disable :all
      Deploy.observers.disable :all
    end

    def db_prepare
      DBPrepareMigration.migrate :up
    end

    def db_clean
      DBPrepareMigration.migrate :down
    end


    def copy_users
      find_each(db[:users]) do |old_user|
        copy_user(old_user)
      end
    end

    def copy_apps
      find_each(db[:apps]) do |old_app|
        app = copy_app(old_app)
        copy_watchers(old_app, app)
        copy_deploys(old_app, app)
      end
    end

    def copy_watchers(old_app, app)
      if old_app["watchers"]
        counter = 0
        total = old_app["watchers"].count
        log "  Start copy watchers, total: #{total}"

        old_app["watchers"].each do |watcher|
          log "    copying [watcher] ##{counter += 1} of #{total} with id '#{watcher['_id']}'"

          copy_watcher(app, watcher)
        end
      end
    end

    def copy_deploys(old_app, app)
      if old_app["deploys"]
        counter = 0
        total = old_app["deploys"].count
        log "  Start copy deploys, total: #{total}"

        deploys = []
        old_app["deploys"].each do |deploy|
          log "    copying [deploy] ##{counter += 1} of #{total} with id '#{deploy['_id']}'"

          deploys << copy_deploy(app, deploy)
          Deploy.import deploys.slice!(0..deploys.count) if deploys.count > 50
        end
        Deploy.import deploys
      end
    end

    def copy_problems
      problems = []
      find_each(db[:problems]) do |old_problem|
        copy_problem(old_problem)
        #if problems.count > 50
          #Problem.import problems
          #problems = []
        #end
      end
      #Problem.import problems
    end

    def copy_comments
      comments = []
      find_each(db[:comments]) do |old_comment|
        comments << copy_comment(old_comment)
        if comments.count > 50
          Comment.import comments
          comments = []
        end
      end
      Comment.import comments
    end

    def copy_errs
      errs = []
      find_each(db[:errs]) do |old_err|
        errs << copy_err(old_err)
        if errs.count > 50
          Err.import errs
          errs = []
        end
      end
      Err.import errs
    end

    def copy_notices
      notices = []
      find_each(db[:notices]) do |old_notice|
        notices << copy_notice(old_notice)
        if notices.count > 50
          Notice.import notices
          notices = []
        end
      end
      Notice.import notices
    end

    def copy_backtraces
      find_each(db[:backtraces]) do |old_backtrace|
        copy_backtrace(old_backtrace)
      end
    end

    private
      def copy_user(old_user)
        user = User.new
        copy_from_mapping(USER_FIELDS_MAPPING, old_user, user)

        # disable validation, cause devise require password. Try create "type" without password validation
        user.save(:validate => false)
        user
      end

      def copy_app(old_app)
        app = App.new
        copy_from_mapping(APP_FIELDS_MAPPING, old_app, app)
        app.save!

        copy_issue_tracker(app, old_app)
        copy_notification_service(app, old_app)

        app
      end

      def copy_issue_tracker(app, old_app)
        return unless old_app["issue_tracker"]
        issue_tracker = app.build_issue_tracker
        copy_from_mapping(ISSUE_TRACKER_FIELDS_MAPPING, old_app["issue_tracker"], issue_tracker)
        app.issue_tracker.type = normalize_issue_tracker_classname(old_app["issue_tracker"]["_type"])

        # disable validate because have problem with different schemas in db
        issue_tracker.save(:validate => false)
      end

      def copy_notification_service(app, old_app)
        return unless old_app["notification_service"]
        notification_service = app.build_notification_service
        copy_from_mapping(NOTIFICATION_SERVICE_FIELDS_MAPPING, old_app["notification_service"], notification_service)
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

      def copy_watcher(app, old_watcher)
        # not app.watchers.new, cause it's reason for memory leak (if you has many watchers)
        watcher = Watcher.new(:app_id => app.id)
        watcher.email = old_watcher["email"]
        if old_watcher["user_id"]
          watcher.user = User.find_by_remote_id(old_watcher["user_id"].to_s)
        end
        watcher.save!
        watcher
      end

      def copy_deploy(app, old_deploy)
        # not app.deploys.new, cause it's reason for memory leak (if you has many deploys)
        deploy = Deploy.new(:app_id => app.id)
        copy_from_mapping(DEPLOY_FIELDS_MAPPING, old_deploy, deploy)
        deploy
      end

      def copy_err(old_err)
        err = Err.new

        problem = Problem.find_by_remote_id(old_err["problem_id"].to_s)
        err.problem = problem

        copy_from_mapping(ERR_FIELDS_MAPPING, old_err, err)

        err
      end

      def copy_notice(old_notice)
        notice = Notice.new

        copy_from_mapping(NOTICE_FIELDS_MAPPING, old_notice, notice)

        err = Err.find_by_remote_id(old_notice["err_id"].to_s)
        notice.err = err

        backtrace = Backtrace.find_by_remote_id(old_err["backtrace_id"].to_s)
        notice.backtrace = backtrace

        notice
      end

      def copy_comment(old_comment)
        comment = Comment.new

        problem = Problem.find_by_remote_id(old_comment["err_id"].to_s) if old_comment["err_id"]
        comment.problem = problem

        user = User.find_by_remote_id(old_comment["user_id"].to_s) if old_comment["user_id"]
        comment.user = user

        copy_from_mapping(COMMENT_FIELDS_MAPPING, old_comment, comment)

        comment
      end

      def copy_problem(old_problem)
        problem = Problem.new

        app = App.find_by_remote_id(old_problem["app_id"].to_s)
        problem.app = app

        copy_from_mapping(PROBLEM_FIELDS_MAPPING, old_problem, problem)

        problem.save!
        problem
      end

      def copy_backtrace(old_backtrace)
        backtrace = Backtrace.new
        copy_from_mapping(BACKTRACE_FIELDS_MAPPING, old_backtrace, backtrace)
        copy_backtrace_lines(backtrace, old_backtrace)

        backtrace.save!
        backtrace
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
        copy_from_mapping(BACKTRACE_LINE_FIELDS_MAPPING, old_line, line)

        line
      end

      def find_each(collection)
        counter = 0
        total = collection.count
        log "Start copy #{collection.name}, total: #{total}"

        collection.find({}, :timeout => false) do |cursor|
          counter = 0
          cursor.each do |item|
            log "  copying [#{collection.name}] ##{counter += 1} of #{total} with id '#{item["_id"]}'"
            yield item
          end
        end
      end

      def copy_from_mapping(map_hash, copy_from, copy_to)
        map_hash.each do |from_key, to_key|
          if from_key.respond_to? :call
            copy_to[to_key] = from_key.call(copy_from)
          else
            copy_to[to_key] = copy_from[from_key] if copy_from.has_key? from_key
          end
        end
      end

      def log(message)
        puts "[#{Time.current.to_s(:db)}] #{message}"
      end
  end

end
