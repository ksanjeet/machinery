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

require_relative "../spec_helper"

describe "changed_managed_files model" do
  let(:scope) {
    json = create_test_description_json(scopes: ["changed_managed_files"])
    Machinery::ChangedManagedFilesScope.from_json(JSON.parse(json)["changed_managed_files"])
  }

  it_behaves_like "Scope"
  it_behaves_like "FileScope"

  specify { expect(scope).to be_a(Machinery::ChangedManagedFilesScope) }
  specify { expect(scope.first).to be_a(Machinery::ChangedManagedFile) }

  it "has correct scope name" do
    expect(Machinery::ChangedManagedFilesScope.new.scope_name).to eq("changed_managed_files")
  end
end
