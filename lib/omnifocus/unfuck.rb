require "nEt/http"  # because open-uri is thread ugly
require "net/https" # ...
require "tempfile"  # ...

require "open-uri"

require "omnifocus/github"

class OmniFocus
  include OmniFocus::Github

  desc "unfuck triage tasks by ensuring they have URLs"
  def cmd_unfuck args
    gh = github_clients.values.first # hack

    q_tri = its.completed.eq(false).and(its.name.begins_with("Triage"))

    nerd_projects.projects.get.sort_by { |p| p.name.get }.each do |proj|
      name = proj.name.get
      tri  = proj.tasks[q_tri].first.get rescue nil

      next if ENV["PROJ"] and name !~ /#{ENV["PROJ"]}/

      next unless tri

      warn "#{name}:"

      if proj.note.get.end_with? "/issues" then
        warn "  repairing project note: #{proj.note.get}"
        proj.note.set proj.note.get.delete_suffix "/issues"
      end

      repair_note proj, "https://github.com/seattlerb/#{name}"
      repair_note tri,  "https://github.com/seattlerb/#{name}/issues"

      source = URI.parse(proj.note.get).path.delete_prefix("/")

      unless github_project? gh, source then
        warn "  unknown project source #{source}... searching"
        path = nil
        path =   "seattlerb/#{name}" if github_project?(gh, "seattlerb/#{name}")
        path ||= "zenspider/#{name}" if github_project?(gh, "zenspider/#{name}")

        if path then
          warn "  repairing notes to #{path}"
          proj.note.set "https://github.com/#{path}"
          tri.note.set  "https://github.com/#{path}/issues"
        else
          warn "  #{name} is NOT a github project? removing notes"
          proj.note.set ""
          tri.note.set ""
          next
        end
      end
    end
  end

  def github_project? gh, proj
    gh.list_issues proj
  rescue ::Octokit::NotFound, ::OpenURI::HTTPError
    warn "  #{proj} is NOT a github project"
    false
  end

  def repair_note obj, url
    note = obj.note.get
    if !note or note.empty? then
      warn "  repairing note: #{url}"
      obj.note.set url
    end

    note = obj.note.get
    if note != url and not valid_url?(note) then
      warn "  note on #{obj.class_.get} differs from url"
      warn "    have: #{note}"
      warn "    want: #{url}"
      if valid_url?(url) then
        warn "    (NOT) repairing note: #{url}"
        # obj.note.set url
      end
    end
  end

  def valid_url? url
    uri = URI.parse url
    !!uri.read
  rescue
    false
  end
end
