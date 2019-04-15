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

require_relative "spec_helper"

describe Machinery::Kickstart do
  capture_machinery_output
  initialize_system_description_factory_store

  let(:expected_profile) {
    File.read(File.join(Machinery::ROOT, "spec/data/kickstart/simple.cfg"))
  }
  let(:description) {
    create_test_description(
      store_on_disk: true,
      extracted_scopes: [
        "changed_config_files",
        "changed_managed_files",
        "unmanaged_files"
      ],
      scopes: [
        "os_redhat7",
        "packages",
        "patterns",
        "repositories",
        "users_with_passwords",
        "groups",
        "services"
      ]
    )
  }

  describe "#initialize" do
    it "raises exception when OS is not supported for exporting" do
      allow_any_instance_of(Machinery::SystemDescription).to receive(:os).
        and_return(Machinery::OsSuse.new)
      description.os.name = "SLES"
      expect {
        Machinery::Kickstart.new(description)
      }.to raise_error(
        Machinery::Errors::ExportFailed, /SLES/
      )
    end
  end

  describe "#profile" do
    it "handles quotes in changed links" do
      description["changed_managed_files"] <<
        Machinery::ChangedManagedFile.new(
          name: "/opt/test-quote-char/link",
          package_name: "test-data-files",
          package_version: "1.0",
          status: "changed",
          changes: ["link_path"],
          mode: "777",
          user: "root",
          group: "root",
          type: "link",
          target: "/opt/test-quote-char/target-with-quote'-foo"
        )
      kickstart = Machinery::Kickstart.new(description)
      expect(kickstart.profile(given_directory)).to include(
        "ln -s '/opt/test-quote-char/target-with-quote'\\\''-foo' '/mnt/opt/test-quote-char/link'"
      )
    end

    it "creates the expected profile" do
      kickstart = Machinery::Kickstart.new(description)
      expect(kickstart.profile(given_directory)).to eq(expected_profile)
    end

    it "does not ask for export URL if files weren't extracted" do
      [
        "changed_config_files",
        "changed_managed_files",
        "unmanaged_files"
      ].each do |scope|
        description[scope].extracted = false
      end
      kickstart = Machinery::Kickstart.new(description)

      expect(kickstart.profile(given_directory)).not_to include("Enter URL to system description")
    end
  end

  describe "#write" do
    let(:ip) { "192.168.0.35" }
    before(:each) do
      kickstart = Machinery::Kickstart.new(description)
      @output_dir = given_directory
      allow(kickstart).to receive(:outgoing_ip).and_return(ip)
      kickstart.write(@output_dir)
      expect(captured_machinery_output).to include(
        "Note: The permssions of the KickStart directory are restricted to be only" \
          " accessible by the current user. Further instructions are provided by the " \
          "README.md in the exported directory."
      )
    end

    it "copies over the system description" do
      expect(File.exist?(File.join(@output_dir, "manifest.json"))).to be(true)
    end

    it "adds the ks.cfg" do
	    expect(File.exist?(File.join(@output_dir, "ks.cfg"))).to be(true)
    end

    it "adds unmanaged files filter list" do
      expect(File.exist?(File.join(@output_dir, "unmanaged_files_kickstart_excludes"))).to be(true)
    end

    it "filters log files from the Kickstart export" do
      expect(File.read(File.join(@output_dir, "unmanaged_files_kickstart_excludes"))).
        to include("var/log/*")
    end

    it "adds the kickstart export readme" do
      expect(File.exist?(File.join(@output_dir, "README.md"))).to be(true)
    end

    it "adds the ip of the outgoing network to the readme" do
      file = File.read(File.join(@output_dir, "README.md"))
      expect(file).to include("ks=http://#{ip}:8000/ks.cfg")      
      expect(file).to include("inst.ks=http://#{ip}:8000/ks.cfg")
    end

    it "adds the kickstart export path to the readme" do
      file = File.read(File.join(@output_dir, "README.md"))
      expect(file).to include("cd #{@output_dir}; python -m SimpleHTTPServer")
      expect(file).to include("chmod -R a+rX #{@output_dir}")
    end

    it "restricts permissions of all exported files and dirs to the user" do
      Dir.glob(File.join(@output_dir, "/*")).each do |entry|
        next if entry.end_with?("/README.md")
        if File.directory?(entry)
          expect(File.stat(entry).mode & 0777).to eq(0700), entry
        else
          expect(File.stat(entry).mode & 0777).to eq(0600), entry
        end
      end
    end
  end

  describe "#export_name" do
    it "returns the export name" do
      kickstart = Machinery::Kickstart.new(description)

      expect(kickstart.export_name).to eq("description-kickstart")
    end
  end

  describe "#outgoing_ip" do
    let(:kickstart) { Machinery::Kickstart.new(description) }
    let(:ip_route) {
      "8.8.8.8 via 10.100.255.254 dev em1  src 10.100.2.35 \n    cache "
    }
    let(:ip_no_route) { "RTNETLINK answers: Network is unreachable " }

    it "returns the current outgoing ip" do
      expect(Cheetah).to receive(:run).with(
        "ip", "route", "get", "8.8.8.8", stdout: :capture
      ).and_return(ip_route)
      expect(kickstart.outgoing_ip).to eq("10.100.2.35")
    end

    it "returns ip placeholder if no external route exists" do
      expect(Cheetah).to receive(:run).with(
        "ip", "route", "get", "8.8.8.8", stdout: :capture
      ).and_return(ip_no_route)
      expect(kickstart.outgoing_ip).to eq("<ip>")
    end
  end
end
