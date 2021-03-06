# Copyright (c) 2013-2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com


# This file contains the defaults for machinery's configuration.
# They can be overwritten by the config file.

module Machinery
  class Config < ConfigBase
    def default_config_file
      ENV["MACHINERY_CONFIG_FILE"] || Machinery::DEFAULT_CONFIG_FILE
    end

    def define_entries
      entry("hints",
        default: true,
        description: "Show hints about usage of Machinery in the context of the commands ran by" \
          " the user"
           )
      entry("remote-user",
        default: "root",
        description: "Defines the user which is used to access the inspected system via SSH"
           )
      entry("experimental-features",
        default: false,
        description: "Enable experimental features. See " \
          "https://github.com/SUSE/machinery/wiki/Experimental-Features for more details"
           )
      entry("http_server_port",
        default: 7585,
        description: "TCP port used by the HTTP server for the HTML view"
           )
    end

    def deprecated_entries
      ["perform_support_check"]
    end
  end
end
