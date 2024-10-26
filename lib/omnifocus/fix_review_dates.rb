class OmniFocus
  desc "Fix review dates. Use -n to no-op"
  def cmd_fix_review_dates args # TODO: merge into reschedule
    skip = ARGV.first == "-n"

    projs = all_projects.group_by { |proj| proj.review_interval[:steps] }

    projs.each do |k, a|
      # helps stabilize and prevent random shuffling
      projs[k] = a.sort_by { |p| [p.next_review_date, p.name] }
    end

    now = hour 0
    fri = if now.wday == 5 then
            now
          else
            now - 86400 * (now.wday-5)
          end

    no_autosave_during do
      projs.each do |unit, a|
        day = fri

        steps = (a.size.to_f / unit).ceil

        a.each_with_index do |proj, i|
          if proj.next_review_date != day then
            warn "Fixing #{unit} #{proj.name} review date to #{day}"
            proj.thing.next_review_date.set day unless skip
          end

          day += 86400 * 7 if (i+1) % steps == 0
        end
      end
    end
  end
end
