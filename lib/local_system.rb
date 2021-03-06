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

class Machinery::LocalSystem < Machinery::System
  @@os = nil

  class << self
    def os
      unless @@os
        description = Machinery::SystemDescription.new(
          "localhost",
          Machinery::SystemDescriptionMemoryStore.new
        )
        inspector = Machinery::OsInspector.new(
          Machinery::System.for("localhost"),
          description
        )
        inspector.inspect(nil)
        @@os = description.os
      end
      @@os
    end

    def validate_existence_of_package(package)
      validate_existence_of_packages([package])
    end

    def validate_existence_of_packages(packages)
      missing_packages = []
      needed_modules = []

      packages.each do |package|
        begin
          Cheetah.run("rpm", "-q", package)
        rescue Cheetah::ExecutionFailed
          missing_packages << package
          needed_module = os.module_required_by_package(package)
          if needed_module
            needed_modules << package
            if needed_module
              output = <<-EOF
You need the package '#{package}' from module '#{needed_module}'. You can install it as follows:
If you haven't selected the module '#{needed_module}' before, run `yast2 scc` and choose 'Select Extensions' and activate '#{needed_module}'.
Run `zypper install #{package}` to install the package.
              EOF
              raise(Machinery::Errors::MissingRequirement.new(output))
            end
          end
        end
      end

      unless missing_packages.empty?
        count = missing_packages.count
        error_string = <<-EOF
You need the #{Machinery.pluralize(count, "package")} '#{missing_packages.join("\',\'")}'.
You can install it by running `zypper install #{missing_packages.join(" ")}`.
        EOF
        raise(Machinery::Errors::MissingRequirement.new(error_string))
      end
    end

    def validate_existence_of_command(command, package)
      Cheetah.run("which", command)
    rescue Cheetah::ExecutionFailed
      output = <<-EOF
You need the command '#{command}' from package '#{package}'.
You can install it by running `zypper install #{package}`.
      EOF
      raise(Machinery::Errors::MissingRequirement.new(output))
    end

    def matches_architecture?(arch)
      os.architecture == arch
    end

    def validate_architecture(arch)
      unless matches_architecture?(arch)
        raise(Machinery::Errors::UnsupportedArchitecture.new(
          "This operation is not supported on architecture '#{os.architecture}'."
        ))
      end
    end
  end

  def type
    "local"
  end

  def requires_root?
    true
  end

  def run_command(*args)
    if args.last.is_a?(Hash) && args.last[:disable_logging]
      cheetah_class = Cheetah
    else
      cheetah_class = Machinery::LoggedCheetah
    end

    with_env(
      "LANGUAGE" => "",
      "LC_ALL" => locale
    ) do
      cheetah_class.run(*args)
    end
  end

  # Retrieves files specified in filelist from the local system and raises an
  # Machinery::Errors::RsyncFailed exception when it's not successful. Destination is
  # the directory where to put the files.
  def retrieve_files(filelist, destination)
    begin
      Machinery::LoggedCheetah.run(
        "rsync",
        "--chmod=go-rwx",
        "--files-from=-",
        "/",
        destination,
        stdout: :capture,
        stdin: filelist.join("\n")
        )
    rescue Cheetah::ExecutionFailed => e
      raise Machinery::Errors::RsyncFailed.new(
      "Could not rsync files from localhost. \n" \
      "Error: #{e}\n" \
      "If you lack read permissions on some files you may want to retry as user root or specify\n" \
      "the fully qualified host name instead of localhost in order to connect as root via ssh."
    )
    end
  end

  # Reads a file from the System. Returns nil if it does not exist.
  def read_file(file, _options = {})
    File.read(file)
  rescue Errno::ENOENT
    # File not found, return nil
    return
  end

  # Copies a file to the local system
  def inject_file(source, destination)
    FileUtils.copy(source, destination)
  rescue => e
    raise Machinery::Errors::InjectFileFailed.new(
      "Could not inject file '#{source}' to local system.\n" \
      "Error: #{e}"
    )
  end

  # Removes a file from the System
  def remove_file(file)
    File.delete(file) if File.exist?(file)
  rescue => e
    raise Machinery::Errors::RemoveFileFailed.new(
      "Could not remove file '#{file}' on local system'.\n" \
      "Error: #{e}"
    )
  end
end
