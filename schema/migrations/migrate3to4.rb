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

class Migrate3To4 < Migration
  desc <<-EOT
    Schema version 4 adds a "type" attribute to changed_managed_files in order to support other file
    types like links.
  EOT

  def migrate
    if @hash.has_key?("changed_managed_files")
      @hash["changed_managed_files"]["files"].each do |file|
        file["type"] = "file"
      end
    end
  end
end
