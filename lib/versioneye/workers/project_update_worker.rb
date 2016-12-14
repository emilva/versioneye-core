class ProjectUpdateWorker < Worker

# This worker handels the period update jobs (DAILY, WEEKLY, MONTHLY)
# And the single project updates.

  def work
    connection = get_connection
    connection.start
    channel = connection.create_channel
    channel.prefetch(1)
    queue   = channel.queue("project_update", :durable => true)

    multi_log " [*] ProjectUpdateWorker waiting for messages in #{queue.name}. To exit press CTRL+C"

    begin
      queue.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
        multi_log " [x] ProjectUpdateWorker received #{body}"
        process body
        channel.ack(delivery_info.delivery_tag)
        multi_log " [x] ProjectUpdateWorker job done #{body}"
      end
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
      connection.close
    end
  end


  def process msg
    if msg.match(/project_/)
      update_project msg
      return
    end
    log.info "Nothing matched for #{msg}"
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def update_project msg
    pp  = msg.gsub("project_", "")
    pps = pp.split(":::")
    project_id = pps[0]
    send_email = false
    send_email = true if pps[1].eql?('true')
    project = Project.find project_id
    if project.nil?
      log.error " [x] ProjectUpdateWorker no project found for #{project_id}"
      return nil
    end

    log.info " - ProjectUpdateService.update #{project_id}"
    ProjectUpdateService.update project, send_email

    task_key    = "task_#{project.ids}"
    task_status = cache.set( task_key, ProjectUpdateService::A_TASK_DONE, ProjectUpdateService::A_TASK_TTL )
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


end
