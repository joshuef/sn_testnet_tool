resource "digitalocean_droplet" "node_builder" {
    count = var.builder_count
    image = "140808087" #safenode-builder, id from `doctl compute snapshot list`
    name = "${terraform.workspace}-safenode-builder"
    region = "lon1"
    size = var.build-size
    ssh_keys = var.ssh_keys

    connection {
        host = self.ipv4_address
        user = "root"
        type = "ssh"
        timeout = "1m"
        # agent=true
        private_key = file(var.pvt_key)
    }

    provisioner "remote-exec" {
        inline = [
        "echo 'ClientAliveInterval 300' >> /etc/ssh/sshd_config",
        "echo 'ClientAliveCountMax 5' >> /etc/ssh/sshd_config",
        "systemctl restart sshd",
        ]
    }


    # lets checkout the given commit first so we can fail fast if there's an issue
    provisioner "remote-exec" {
        inline = [
            "cd safe_network",
            "git remote add ${var.repo_owner} https://github.com/${var.repo_owner}/safe_network || true",
        ]
    }
    # lets checkout the given commit first so we can fail fast if there's an issue
    provisioner "remote-exec" {
        inline = [
            "cd safe_network",
            "git branch -D ${var.commit_hash} || true", # delete local branch if it exists
            "git fetch ${var.repo_owner} -qf",
        ]
    }
  
    provisioner "remote-exec" {
        inline = [
            "cd safe_network",
            "git checkout ${var.repo_owner}/${var.commit_hash}"
        ]
    }

    # provisioner "remote-exec" {
    #     inline = [
    #         "export DEBIAN_FRONTEND=noninteractive",
    #        "apt-get update",
    #         # don't add apt-install steps here. move them down before `cargo build` to prevent file locks
    #         # "bash",
    #         <<-EOT
    #             while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    #                 sleep 1
    #             done
    #             while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
    #                 sleep 1
    #             done
    #             while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
    #                 sleep 1
    #             done
    #             while sudo fuser /var/lib/apt/lists/ >/dev/null 2>&1 ; do
    #                 sleep 1
    #             done
    #             if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
    #                 while sudo fuser /var/log/unattended-upgrades/unattended-upgrades.log >/dev/null 2>&1 ; do
    #                 sleep 1
    #                 done
    #             fi
    #         EOT
    #     ]
    # }

    provisioner "remote-exec" {
        inline = [
            # avoid modals for kernel upgrades hanging setup
            # "export DEBIAN_FRONTEND=noninteractive",
            "cd safe_network",
            "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -q --default-host x86_64-unknown-linux-gnu --default-toolchain stable -y",
            ". $HOME/.cargo/env",
            "apt update",
            # "apt -qq install musl-tools build-essential -y",
            # "apt -qq install build-essential -y",
            # "rustup target add x86_64-unknown-linux-musl",
            # "cargo -q build --release --target=x86_64-unknown-linux",
            # "RUSTFLAGS=\"-C debuginfo=2\" cargo build --release --bins",
            "cargo build --release --bin safenode",
            "cargo build --release --bin safe",
            "cargo build --release --bin faucet",
            "git log -1"
        ]
    }

    provisioner "local-exec" {
        command = <<EOH
            mkdir -p ~/.ssh/
            mkdir -p workspace/${terraform.workspace}
            touch ~/.ssh/known_hosts
            ssh-keyscan -H ${self.ipv4_address} >> ~/.ssh/known_hosts
        EOH
    }
    provisioner "local-exec" {
        command = "rsync -z root@${self.ipv4_address}:/root/safe_network/target/release/safe ./workspace/${terraform.workspace}/safe"
    }
    provisioner "local-exec" {
        command = "rsync -z root@${self.ipv4_address}:/root/safe_network/target/release/safenode ./workspace/${terraform.workspace}/safenode"
    }
    provisioner "local-exec" {
        command = "rsync -z root@${self.ipv4_address}:/root/safe_network/target/release/faucet ./workspace/${terraform.workspace}/faucet"
    }
}
