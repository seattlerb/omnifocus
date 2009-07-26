module OmniFocus::Rubyforge
  RF_URL = "http://rubyforge.org"

  def rubyforge
    unless defined? @rubyforge then
      @rubyforge = RubyForge.new
      @rubyforge.configure
    end
    @rubyforge
  end

  def login_to_rubyforge
    m, login_url = mechanize, "/account/login.php"

    m.get("#{RF_URL}#{login_url}").form_with(:action => login_url) do |f|
      f.form_loginname = rubyforge.userconfig["username"]
      f.form_pw        = rubyforge.userconfig["password"]
    end.click_button
  end

  def populate_rubyforge_tasks
    home = login_to_rubyforge

    # nuke all the tracker links on "My Page" after "My Submitted Items"
    node = home.root.xpath('//tr[td[text() = "My Submitted Items"]]').first
    loop do
      prev, node = node, node.next
      prev.remove
      break unless node
    end

    group_ids = rubyforge.autoconfig["group_ids"].invert

    rubyforge_tickets = home.links_with(:href => /^.tracker/)
    rubyforge_tickets.each do |link|
      if link.href =~ /func=detail&aid=(\d+)&group_id=(\d+)&atid=(\d+)/ then
        ticket_id, group_id = $1.to_i, $2.to_i
        group = group_ids[group_id]

        next unless group

        if existing[ticket_id] then
          bug_db[existing[ticket_id]][ticket_id] = true
          next
        end

        warn "scanning ticket RF##{ticket_id}"
        details = link.click.form_with :action => /^.tracker/
        select  = details.field_with   :name   => "category_id"
        project = select.selected_options.first
        project = project ? project.text.downcase : group
        project = group if project =~ /\s/
        title   = "RF##{ticket_id}: #{link.text}"
        url     = "#{RF_URL}/#{link.href}"

        bug_db[project][ticket_id] = [title, url]
      end
    end
  end
end
