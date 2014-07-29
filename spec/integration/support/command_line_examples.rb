# Copyright (c) 2013-2014 SUSE LLC
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

shared_examples "CLI" do
  describe "CLI" do
    it "throws an error on invalid command" do
      expect { @machinery.run_command(
        "cd; machinery/bin/machinery invalid_command",
        :as => "vagrant",
        :stdout => :capture
      ) }.to raise_error(ExecutionFailed)
    end

    it "processes help option" do
      output = @machinery.run_command(
        "cd; machinery/bin/machinery -h",
        :as => "vagrant",
        :stdout => :capture
      )
      expect(output).to include("COMMANDS")
      expect(output).to include("help")
      expect(output).to include("GLOBAL OPTIONS")
    end

    it "processes help option for subcommands" do
      output = @machinery.run_command(
        "cd; machinery/bin/machinery inspect --help",
        :as => "vagrant",
        :stdout => :capture
      )
      expect(output).to include("machinery [global options] inspect [command options] HOSTNAME")
    end

    it "does not offer --no-help or unneccessary negatable options" do
      global_output = @machinery.run_command(
        "cd; machinery/bin/machinery --help",
        :as => "vagrant",
        :stdout => :capture
      )
      inspect_help_output = @machinery.run_command(
        "cd; machinery/bin/machinery inspect --help",
        :as => "vagrant",
        :stdout => :capture
      )
      show_help_output = @machinery.run_command(
        "cd; machinery/bin/machinery inspect --help",
        :as => "vagrant",
        :stdout => :capture
      )
      expect(global_output).to_not include("--[no-]help")
      expect(inspect_help_output).to_not include("--[no-]")
      expect(show_help_output).to_not include("--[no-]no-pager")
    end

    describe "inspect" do
      it "fails inspect for non existing scope" do
        expect { @machinery.run_command(
          "cd; sudo machinery/bin/machinery inspect localhost --scope=foobar --name=test",
          :as => "vagrant",
          :stdout => :capture
        ) }.to raise_error(ExecutionFailed, /The following scopes are not supported: foobar/)
      end
    end

    describe "build" do
      it "fails without an output path" do
        expect { @machinery.run_command(
          "cd; machinery/bin/machinery build test",
          :as => "vagrant",
          :stdout => :capture
        ) }.to raise_error(ExecutionFailed, /image-dir is required/)
      end

      it "fails without a name" do
        expect { @machinery.run_command(
          "cd; machinery/bin/machinery build --image-dir=/tmp/",
          :as => "vagrant",
          :stdout => :capture
        ) }.to raise_error(ExecutionFailed, /was called with missing argument/)
      end
    end
  end
end
