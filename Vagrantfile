# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "blinkreaction/boot2docker"

  #config.vm.provision "shell", inline: "cd /home/docker && wget https://github.com/sirisaacnuketon/handsondevops/archive/master.zip && unzip master.zip"
  config.vm.network "forwarded_port", guest: 4000, host: 40000 
  config.vm.network "forwarded_port", guest: 80 , host: 800
  config.ssh.insert_key = true

  config.vm.synced_folder "./", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end
end
