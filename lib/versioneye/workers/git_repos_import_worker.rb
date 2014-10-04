class GitReposImportWorker < Worker


  def work
    connection = get_connection
    connection.start
    channel = connection.create_channel
    queue   = channel.queue("git_repos_import", :durable => true)

    log_msg = " [*] Waiting for messages in #{queue.name}. To exit press CTRL+C"
    puts log_msg
    log.info log_msg

    begin
      queue.subscribe(:ack => true, :block => true) do |delivery_info, properties, body|
        msg = " [x] Received #{body}"
        puts msg
        log.info msg

        import_all_repos msg

        channel.ack(delivery_info.delivery_tag)
      end
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
      connection.close
    end
  end


  private

    def import_all_repos msg
      provider = msg.split(":::").first
      user_id = msg.split(":::").last
      user = User.find user_id

      if provider.eql?("stash")
        import_stash_repos user
      end

    end

    def import_stash_repos user
      return nil if user.nil?

      user_task_key = "#{user[:username]}-stash"
      log.info "Fetch Repositories for #{user_task_key} from Stash and cache them in DB."

      cache.set( user_task_key, BitbucketService::A_TASK_RUNNING, BitbucketService::A_TASK_TTL )
      BitbucketService.cache_user_all_repos( user )
      cache.set( user_task_key, BitbucketService::A_TASK_DONE, BitbucketService::A_TASK_TTL )
      log.info "Job done for #{user_task_key}"
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
    end


end
