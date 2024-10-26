require "net/http"  # because open-uri is thread ugly
require "net/https" # ...
require "tempfile"  # ...

require "open-uri"
require "uri"
require "json"

$: << File.expand_path("~/Work/p4/zss/src/worker_bee/dev/lib/")
require "worker_bee"

class OmniFocus
  # def window
  #   omnifocus.documents.first.document_windows.first
  # end

  desc "Triage nerd projects with open issues and/or PRs"
  def cmd_triage args
    active       = its.completed.eq(false)
    is_due       = its.due_date.lt(Time.now + (86400/3))
    http_note    = its.note.begins_with("http")

    # note of tasks of flattened tag "Triaging" whose
    #   completed is false and due date < today and note starts with "HTTP"

    tasks = self._context("Triaging").tasks[active.and(is_due).and(http_note)]
    urls = tasks.note.get

    # triage = Triage.new

    u2t = urls.zip(tasks.get).map { |u, t| # TODO: use api to get redirs
      d = File.dirname u
      [["#{d}/pulls",  t],
       ["#{d}/issues", t]]
    }.flatten(1).to_h

    t0 = Time.now
    td = x = nil
    urls_to_triage = Triage.new.process u2t.keys
    td = Time.now - t0

    puts td

    tasks_to_triage = urls_to_triage.map { |u| u2t[u] }.uniq
    _tasks_to_skip   = tasks.get - tasks_to_triage

    open_safari_tabs urls_to_triage unless urls_to_triage.empty?

    tasks.mark_complete

    # this seems to be deleting everything and breaking my repeats
    # tasks_to_skip.each do |task| # complete + delete == skip
    #   task.delete
    # end
  end

  def open_safari_tabs urls
    safari = Appscript.app("Safari")

    safari.activate
    _document = safari.make new: :document # this seems so dumb
    window = safari.windows[1]

    dead = window.current_tab.get

    urls.each do |url|
      window.make(:new => :tab, :with_properties => {:URL => url})
    end

    dead.delete
  end

  class Triage
    attr_reader :oauth

    def initialize
      @oauth = config_oauth_token
    end

    def process urls
      require "worker_bee"

      bee = WorkerBee.new

      bee.input(*urls)
      bee.work       { |url| url_to_api    url } # -> api_url
      bee.work(n:20) { |url| url_to_ary    url } # -> [ issues_or_pulls ]
      bee.work       { |ary| issues_to_url ary } # -> url_to_check
      bee.compact                                # -> url
      bee.results.sort
    end

    def url_to_api url
      url      = "https://github.com/#{url}/issues" unless url.start_with? "http"
      uri      = URI.parse url
      uri.host = "api.github.com"
      uri.path = "/repos#{uri.path}"
      uri.to_s
    end

    def url_to_ary url
      ary = get url
      ary.reject! { |h| h["pull_request"] } if url =~ /issues$/
      ary
    end

    def issues_to_url ary
      payload_to_url ary.first
    end

    def payload_to_url payload, sub = ""
      payload && payload["html_url"].sub(/\/\d+$/, sub).sub(/pull$/, "pulls")
    end

    def get url
      $stderr.print "."
      uri = URI.parse "#{url.sub(/\{.*?\}$/, "")}?per_page=100"
      JSON.load uri.read("Authorization" => "token #{oauth}")
    rescue => e
      warn "ERROR processing %p: %s" % [url, e.message]
      raise
    end

    def config_oauth_token
      token = `gh auth token`.chomp
      abort "Please set git config github.oauth-token" if token.empty?
      token
    end
  end
end
