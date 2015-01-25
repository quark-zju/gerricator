require 'json'
require 'shellwords'
require 'tempfile'
require_relative 'git'


class Arcanist < Struct.new(:conduit_uri, :user, :cert)

  def diff work_dir, callsign, commit: 'HEAD^', differential_id: nil, message: nil, reviewers: ''
    arcrc = write_arcrc
    temps = [arcrc]
    args = ['--no-ansi', '--conduit-uri', conduit_uri, '--config', "repository.callsign=#{callsign}", '--arcrc-file', arcrc.path]

    if differential_id
      # update existing diff
      args += ['--update', differential_id.to_s, '--message', message || 'Update']
    else
      # create new diff
      tmp = Tempfile.create 'arcmsg'
      tmp.write <<"EOS"
#{message || Git::message(work_dir)}

Test Plan:
N/A (imported by gerricator)

Reviewers: #{[*reviewers].join(', ')}
EOS
      tmp.flush
      temps << tmp
      args += ['--create', '--message-file', tmp.path]
    end

    Dir.chdir work_dir do
      cmd = Shellwords.join(['arc', 'diff', *args, commit])
      result = `#{cmd}`

      if not differential_id
        differential_id = result[/#{File.join(conduit_uri, 'D')}(\d+)/, 1]
      end
    end

    differential_id
  ensure
    temps.each do |t|
      File.unlink(t) if t && File.exists?(t)
    end
  end

  private

    def write_arcrc
      Tempfile.create('arcrc').tap do |t|
        content = {
          hosts: {
            File.join(conduit_uri, 'api/') => {
              user: user,
              cert: cert,
            }
          }
        }
        t.write JSON.dump(content)
        t.flush
      end
    end

end
