
namespace :rubber do

  namespace :puma do

    rubber.allow_optional_tasks(self)

    before "deploy:stop", "rubber:puma:stop"
    after "deploy:start", "rubber:puma:start"
    after "deploy:restart", "rubber:puma:upgrade"

    desc "Stops the puma server"
    task :stop, :roles => :puma do
      rsudo "service puma stop"
    end

    desc "Starts the puma server"
    task :start, :roles => :puma do
      rsudo "service puma start"
    end

    desc "Restarts the puma server"
    task :restart, :roles => :puma do
      rsudo "service puma restart"
    end

    desc "Reloads the puma web server"
    task :upgrade, :roles => :puma do
      rsudo "service puma upgrade"
    end

    desc "Forcefully kills the puma server"
    task :kill, :roles => :puma do
      rsudo "service puma kill"
    end

    desc "Display status of the puma web server"
    task :status, :roles => :puma do
      rsudo "service puma status || true"
      rsudo "ps -eopid,user,cmd | grep puma || true"
      # rsudo "netstat -tupan | grep puma || true"
    end

  end

end
