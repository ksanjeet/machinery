# Copyright (c) 2013-2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com

class Machinery::Kickstart < Machinery::Exporter
  attr_accessor :name

  def initialize(description)
    @name = "kickstart"
    @chroot_scripts = []
    @system_description = description
    @system_description.assert_scopes(
      "os",
      "packages"
    )
    check_exported_os
    unless description.users
      Machinery::Ui.puts(
        "\nWarning: Exporting a description without the scope 'users' as KickStart" \
        " profile will result in a root account without a password which prevents" \
        " logging in.\n" \
        "So either inspect or add the scope 'users' before the export or" \
        " add a section for the root user to the KickStart profile."
      )
    end
  end

  def write(output_dir)
    FileUtils.cp(
      File.join(Machinery::ROOT, "export_helpers/unmanaged_files_#{@name}_excludes"),
      output_dir
    )
    FileUtils.chmod(0600, File.join(output_dir, "unmanaged_files_#{@name}_excludes"))
    readme = File.read(File.join(Machinery::ROOT, "export_helpers/kickstart_export_readme.md"))
    readme.gsub!("<ip>", outgoing_ip)
    readme.gsub!("<path>", output_dir)
    File.write(File.join(output_dir, "README.md"), readme)
    Dir["#{@system_description.description_path}/*"].each do |content|
      FileUtils.cp_r(content, output_dir, preserve: true)
    end
#    Executing profile method to write to ks.cfg file
    profile(output_dir)
    FileUtils.chmod(0600, File.join(output_dir, "ks.cfg"))
    Machinery::Ui.puts(
      "Note: The permssions of the KickStart directory are restricted to be" \
        " only accessible by the current user. Further instructions are" \
        " provided by the README.md in the exported directory."
    )
  end

  def export_name
    "#{@system_description.name}-kickstart"
  end


  def profile(output_dir)
    File.open(File.join(output_dir, "ks.cfg"),"w") do |f|
      f.write("lang en_us.UTF-8" +
        "\ngraphical" +
        "\ninstall" +
        "\neula --agreed" +
        "\nauth --enableshadow --passalgo=sha512" +
        "\ncdrom" +
        "\nfirstboot --enabled" +
        "\nclearpart --all --initlabel" +
        "\npart /boot --fstype ext4 --size=500" +
        "\npart swap --size=1024" +
        "\npart / --fstype ext4 --size=13480 --grow --asprimary" +
        "\nkeyboard us" +
        "\nrootpw --iscrypted $6$bNjXyviGZwK4X3yA$51rtDgkzad9CVE5KkRAltkQSiXoLJxY46oLLURaJ2mVcKEbDsf1tR3BmKQrk8hKS2fBerlBajBjGHXDBQRH261" +
        "\nnetwork --bootproto=dhcp"+
        "\nbootloader --append=\" crashkernel=auto\" --location=mbr" +
        "\ntimezone Asia/Kolkata --isUtc")
    end
    File.open(File.join(output_dir, "ks.cfg"),"a") do |f|
      f.write(apply_repositories)
      f.write(apply_packages)
      f.write(apply_users)
      f.write(apply_groups)
      f.write(apply_services_enabled)
      f.write(apply_services_disabled)
      apply_changed_files("changed_config_files")
      apply_changed_files("changed_managed_files")
      apply_unmanaged_files
      f.write(apply_url_extraction)
      f.write("\n%post --nochroot --log=/mnt/sysimage/root/post-install.log \n")
      f.write(@chroot_scripts.join("\n"))
      f.write("\n%end")
    end
 end

  def outgoing_ip
    output = Cheetah.run("ip", "route", "get", "8.8.8.8", stdout: :capture)
    output[/ src ([\d\.:]+)\s*$/, 1] || "<ip>"
  end

  private

  def check_exported_os
    unless @system_description.os.is_a?(Machinery::OsRedhat)
      raise Machinery::Errors::ExportFailed.new(
        "Export is not possible because the operating system " \
        "'#{@system_description.os.display_name}' is not supported."
      )
    end
  end

  def apply_repositories
    return unless @system_description.repositories
    ret_val=""
        @system_description.repositories.each do |repository|
        ret_val += "\nrepo --name=" + repository.alias.to_s + " --baseurl=" +  repository.url.to_s.chop.reverse.chop.reverse  
      end
    return ret_val
    end

  def apply_packages
    return unless @system_description.packages
    ret_val="\n%packages"
      @system_description.packages.each do |package|
        ret_val += "\n" + package.name.to_s
      end
      ret_val += "\n%end"
      return ret_val
  end

  def apply_users
    return unless @system_description.users
    ret_val=""
      @system_description.users.each do |user|
      ret_val += "\nuser --name=" + user.name.to_s + " --gecos=\"" + user.comment.to_s + "\" --homedir=" + user.home.to_s + " --password=" + user.encrypted_password.to_s + " --iscrypted" + " --shell=" + user.shell.to_s + " --uid=" + user.uid.to_s + " --gid=" + user.gid.to_s
   end
   return ret_val
  end

  def apply_groups
    return unless @system_description.groups
    ret_val=""
      @system_description.groups.each do |group|
      ret_val += "\ngroup --name=" + group.name.to_s + " --gid=" + group.gid.to_s
      end
      return ret_val
  end

  def apply_services_enabled
    return unless @system_description.services
    ret_val="\nservices --enabled="
        @system_description.services.each do |service|
          name = service.name
          if @system_description.services.init_system == "systemd"
            # Yast can only handle services right now
            next unless name =~ /\.service$/
            name = name.gsub(/\.service$/, "")
          end
          # systemd service states like "masked" and "static" are
          # not supported by Autoyast
          
          if service.enabled?
            ret_val += name + ","  
          end
        end
        return ret_val.chop
  end

  def apply_services_disabled
    return unless @system_description.services
    ret_val="\nservices --disabled="
        @system_description.services.each do |service|
          name = service.name
          if @system_description.services.init_system == "systemd"
            # Yast can only handle services right now
            next unless name =~ /\.service$/
            name = name.gsub(/\.service$/, "")
          end
          # systemd service states like "masked" and "static" are
          # not supported by Autoyast
          
          if service.disabled?
            ret_val += name + ","
          end
        end
        return ret_val.chop
  end

  def apply_url_extraction      #(xml)
    ret_val="\n%pre \n"
    ret_val+='sed -n \'/.*inst.ks\?=\([^ ]*\)\/.*[^\s]*/s//\1/p\' /proc/cmdline > /tmp/description_url'
    ret_val+=" \n%end"
    return ret_val
  end

  def apply_changed_files(scope)
    return unless @system_description.scope_extracted?(scope)

    @system_description[scope].each do |file|
      if file.deleted?
        @chroot_scripts << "rm -rf '#{quote(file.name)}'"
      elsif file.directory?
        @chroot_scripts << <<EOF.strip
chmod #{file.mode} '#{File.join("/mnt/sysimage", quote(file.name))}'
chown #{file.user}:#{file.group} '#{File.join("/mnt/sysimage", quote(file.name))}'
EOF
      elsif file.file?
        url = "`cat /tmp/description_url`/#{URI.escape(File.join(scope, quote(file.name)))}"
        @chroot_scripts << <<EOF.strip
mkdir -p '#{File.join("/mnt/sysimage", File.dirname(quote(file.name)))}'
curl -o '#{File.join("/mnt/sysimage", quote(file.name))}' \"#{url}\"
chmod #{file.mode} '#{File.join("/mnt/sysimage", quote(file.name))}'
chown #{file.user}:#{file.group} '#{File.join("/mnt/sysimage", quote(file.name))}'
EOF
      elsif file.link?
        @chroot_scripts << <<EOF.strip
rm -rf '#{File.join("/mnt/sysimage", quote(file.name))}'
ln -s '#{quote(file.target)}' '#{File.join("/mnt/sysimage", quote(file.name))}'
chown --no-dereference #{file.user}:#{file.group} '#{File.join("/mnt/sysimage", quote(file.name))}'
EOF
      end
    end
  end

  def apply_unmanaged_files
    return unless @system_description.scope_extracted?("unmanaged_files")

    base = Pathname(@system_description.scope_file_store("unmanaged_files").path)
    @chroot_scripts << <<-EOF.chomp.gsub(/^\s+/, "")
      curl -o '/mnt/sysimage/tmp/filter' "`cat /tmp/description_url`/unmanaged_files_#{@name}_excludes"
    EOF

    Dir["#{base}/**/*.tgz"].sort.each do |path|
      relative_path = Pathname(path).relative_path_from(base).to_s
      tarball_name = File.basename(path)
      url = "`cat /tmp/description_url`#{URI.escape(File.join("/unmanaged_files", relative_path))}"

      @chroot_scripts << <<-EOF.chomp.gsub(/^\s+/, "")
        curl -o '/mnt/sysimage/tmp/#{tarball_name}' "#{url}"
        tar -C /mnt/sysimage/ -X '/mnt/sysimage/tmp/filter' -xf '#{File.join("/mnt/sysimage/tmp", tarball_name)}'
        rm '#{File.join("/mnt/sysimage/tmp", tarball_name)}'
      EOF
    end
  end
end
