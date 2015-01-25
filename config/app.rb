require 'active_record'
require 'fileutils'
require 'logger'
require 'sqlite3'
require 'thor'
require 'yaml'
require_relative '../lib/arcanist'
require_relative '../lib/gerrit'
require_relative '../lib/git'

CONFIG_PATH = File.expand_path('~/.config/gerricator/config.yml')

def logger
  @logger ||=\
    if ENV['VERBOSE'] || ENV['DEBUG']
      Logger.new(STDERR)
    else
      Logger.new('/dev/null')
    end
end

def config
  @config ||=\
    begin
      config_path = Dir["{#{CONFIG_PATH},{./,./config/}config.yml{,.example}}"].first
      if config_path.nil?
        raise "Config file not found: #{CONFIG_PATH}"
      else
        logger.info "Config file: #{config_path}"
      end
      YAML::load_file(config_path)
    end
end

def initialize_database
  app_path = File.expand_path('../', __FILE__)
  db_path = config['db_path']
  FileUtils.mkdir_p File.dirname(db_path)
  logger.info "Database: #{db_path}"

  ActiveRecord::Base.logger = logger if STDERR.isatty
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: db_path,
    pool: 5,
    timeout: 5000)
  ActiveRecord::Migrator.migrate(File.join(app_path, '../db/migrate'))
end

def gerrit_bots
  config['gerrit']['bots']
end

def gerrit
  @gerrit ||= Gerrit.new(*%w[base_url username http_password].map {|x| config['gerrit'][x]})
end

def arc
  @arc ||= Arcanist.new(*%w[conduit_uri username certificate].map {|x| config['phabricator'][x]})
end

class Link < ActiveRecord::Base; end

HTTPI.logger = logger

module App; class << self
  # push gerrit change to phabricator
  def push_change change_id, rev_no=nil
    initialize_database
    change = gerrit.change(change_id)
    number = change.number
    project = change.project
    raise "Cannot find change #{change_id}" unless number.to_i > 0

    oid, rev = if rev_no.nil?
                 # last revision
                 change.revisions.max_by {|k, v| v['_number']}
               else
                 change.revisions.find {|k, v| v['_number'] == rev_no.to_i}
               end
    raise "Cannot find revision #{rev_no}" unless rev && oid
    rev_no = rev['_number']
    logger.info "Revision #{rev_no}: #{oid}"

    make_temp_work_dir do |work_dir|
      link = Link.find_by(change_number: change.number)
      if link && link.patch_set_revisions.to_s.split.include?(rev_no.to_s)
        logger.info "Revision #{rev_no} is already at D#{link.differential_id}"
      else
        checkout_commit project, work_dir, oid
        if link
          logger.info "Updating D#{link.differential_id}"
          arc.diff work_dir, config['projects'][project]['phabricator_callsign'], message: "Patchset #{rev_no}", differential_id: link.differential_id
          link.patch_set_revisions = "#{link.patch_set_revisions} #{rev_no}"
          link.save!
        else
          change_url = File.join(config['gerrit']['base_url'], "#/c/#{number}")
          message = "#{Git::message(work_dir)}\nGerrit URL: #{change_url}\n"
          reviewers = [*config['projects'][project]['reviewers']].compact
          reviewers = change.reviewers - gerrit_bots if reviewers.empty?
          logger.info "Creating new diff, reviewers: #{reviewers}"
          differential_id = arc.diff(work_dir, config['projects'][project]['phabricator_callsign'], message: message, reviewers: reviewers)
          link = Link.create! differential_id: differential_id, change_number: number, patch_set_revisions: rev_no
        end
      end
      puts "D#{link.differential_id}"
    end
  end

  def write_example_config force: false
    example_config_path = File.expand_path('../config.yml.example', __FILE__)
    raise "#{CONFIG_PATH} already exists" if !force && File.exists?(CONFIG_PATH)
    FileUtils.mkdir_p File.dirname(CONFIG_PATH)
    FileUtils.cp example_config_path, CONFIG_PATH
    logger.info "Example config written: #{CONFIG_PATH}"
  end

  private

    def sync_repo project
      File.join(File.expand_path(config['local_cache_path']), 'projects', project).tap do |dest|
        url = config['projects'][project]['git_url']
        logger.info "Mirroring #{project} (#{url}) to #{dest}"
        Git::mirror url, dest
      end
    end

    def checkout_commit project, work_dir, oid
      sync_repo(project).tap do |dest|
        logger.info "Checking out #{oid} at #{work_dir}"
        Git::write_commit_tree dest, work_dir, oid
      end
    end

    def make_temp_work_dir
      work_dir = File.join(File.expand_path(config['local_cache_path']), 'work_dir', $$.to_s)
      raise "#{work_dir} already exists" if File.exists?(work_dir)
      begin
        FileUtils.mkdir_p work_dir
        yield work_dir
      ensure
        FileUtils.rm_rf work_dir
      end
    end
end; end
