<%
  @path = "#{Rubber.root}/config/puma.rb"
  current_path = "/mnt/#{rubber_env.app_name}-#{Rubber.env}/current"
%>
workers <%= rubber_env.puma_num_workers %>
directory "<%= Rubber.root %>"

# This loads the application in the master process before forking
# worker processes
# Read more about it here:
# http://puma.bogomips.org/Unicorn/Configurator.html
preload_app!

worker_timeout 30

# This is where we specify the socket.
# We will point the upstream Nginx module to this socket later on
bind "unix:///var/run/puma.sock", :backlog => 64

pidfile "<%= rubber_env.puma_pid_file %>"

# Set the path of the log files inside the log folder of the testapp
#stderr_path "<%= Rubber.root %>/log/puma.stderr.log"
stdout_redirect "<%= Rubber.root %>/log/puma.stdout.log"

# Because of Capistano, we need to tell puma where find the current Gemfile
# Read about Unicorn, Capistrano, and Bundler here:
# http://puma.bogomips.org/Sandbox.html
before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = "<%= current_path %>/Gemfile"
end

before_fork do |server, worker|
  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.
  old_pid = server.config[:pid].sub('.pid', '.pid.oldbin')
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      STDERR.puts "WARNING: old Unicorn process was already killed before new process forked."
    end
  end
  
  # This option works in together with preload_app true setting
  # What is does is prevent the master process from holding
  # the database connection
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end


after_fork do |server, worker|
  # Unicorn master is started as root, which is fine, but let's
  # drop the workers to www-data:www-data
  begin
    uid, gid = Process.euid, Process.egid
    user, group = '<%=rubber_env.app_user %>', '<%=rubber_env.app_user %>'
    target_uid = Etc.getpwnam(user).uid
    target_gid = Etc.getgrnam(group).gid
    worker.tmp.chown(target_uid, target_gid)
    if uid != target_uid || gid != target_gid
      Process.initgroups(user, target_gid)
      Process::GID.change_privilege(target_gid)
      Process::UID.change_privilege(target_uid)
    end
  rescue => e
    if RAILS_ENV == 'development'
      STDERR.puts "WARNING: could not set user on Unicorn workers."
    else
      raise e
    end
  end
  
  # Here we are establishing the connection after forking worker
  # processes
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
