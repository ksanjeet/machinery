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

# = TeeIO
#
# Class to allow the storage and forwarding of input at the same time
# For example if stderr output should be handled by our code but at the
# same time be put out directly
#
# To prevent for example double error messages data can be filtered
# before being passed on to the io_object
# Only the data passed along is filtered, not the data stored in this
# IO object.
class TeeIO < StringIO
  def initialize(io_object, io_filter = [])
    super()
    @io_object = io_object
    @io_filter = Array(io_filter)
  end

  def write(data)
    super
    @io_object.puts(data) unless @io_filter.include?(data)
  end
end
