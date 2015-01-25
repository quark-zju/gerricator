require 'httpi'
require 'json'
require 'base64'

class Gerrit < Struct.new(:base_url, :username, :password)
  
  def get endpoint
    request endpoint
  end

  def post endpoint, body = ''
    request endpoint, method: 'post', body: body.to_s
  end

  class Change < Struct.new(:gerrit, :change_id)
    def number
      @number ||= get['_number']
    end

    def project
      @project ||= get['project']
    end

    def reviewers
      get('reviewers').map {|x| x['username']}.compact
    end

    def revisions
      get('?o=ALL_REVISIONS')['revisions']
    end

    def get subpath=''
      path = File.join("changes/#{change_id}", subpath)
      gerrit.get path
    end
  end

  def change(change_id)
    Change.new(self, change_id)
  end

  private

    def request endpoint, method: 'get', body: nil
      if method == 'get' && body.nil?
        @get_caches ||= {}
        @get_caches[endpoint] ||= send_request endpoint, method: method, body: body
      else
        send_request endpoint, method: method, body: body
      end
    end

    def send_request endpoint, method: 'get', body: nil
      req = HTTPI::Request.new File.join(base_url, username ? 'a' : '', endpoint)
      req.auth.digest username, password if username && password && !username.empty?
      req.auth.ssl.verify_mode = :none
      if body
        req.body = body
        req.headers['Content-Type'] = 'application/json;charset=UTF-8'
      end
      res = HTTPI.send method, req
      content_type = [*res.headers['Content-Type']].last.split(/[ ;]/).first
      case content_type
      when 'application/json'
        JSON.parse res.body.lines[1..-1].join
      when 'text/plain'
        case res.headers['X-FYI-Content-Encoding']
        when 'base64'
          Base64::decode64 res.body
        else
          res.body
        end
      else
        raise "Unknown content type: #{content_type}"
      end
    end

end
