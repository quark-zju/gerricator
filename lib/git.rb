require 'fileutils'
require 'shellwords'


module Git; class << self
  def mirror url, dest
    if File.exists?(dest)
      Dir.chdir(dest) do
        system! 'git', 'fetch', '--tags', '--all', '--force', '--prune'
      end
    else
      FileUtils.mkdir_p dest
      system! 'git', 'clone', '--mirror', url, dest
    end
  end

  def add_shared_objects path, object_path
    raise "object_path is empty" unless object_path
    Dir.chdir path do
      alernates_path = '.git/objects/info/alternates'
      content = (File.read(alernates_path) rescue '')
      return if content.include?(object_path)
      File.write alernates_path, "#{object_path}\n#{content}"
    end
  end

  def init dest
    FileUtils.mkdir_p dest
    Dir.chdir dest do system! 'git', 'init' end
  end

  def checkout dest, commit
    raise "commit is empty" unless commit
    Dir.chdir dest do
      system! 'git', 'checkout', '--quiet', '--force', '--detach', commit
    end
  end

  def message dest, commit='HEAD'
    Dir.chdir dest do
      `git log --format=%B -n 1 #{Shellwords.join([commit])}`.chomp
    end
  end

  def amend dest, message
    Dir.chdir dest do
      system! 'git', 'commit', '--amend', '--message', message
    end
  end

  def write_commit_tree repo_path, dest, commit
    init dest
    object_path = Dir["#{repo_path}/{.git/,}objects"].first
    add_shared_objects dest, object_path
    checkout dest, commit
  end

  private

    def system! *args
      quiet = !ENV['VERBOSE'] && !ENV['DEBUG']
      options = quiet ? {:out => '/dev/null', :err => '/dev/null'} : {}

      raise "Cannot run #{Shellwords.join(args)}" unless system(*args, options)
    end

end; end
