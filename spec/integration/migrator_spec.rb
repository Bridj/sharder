# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sharder::Migrator do
  it "raises a helpful error message if no shard_group is defined" do
    class ShardNotSetMigration < ActiveRecord::Migration::Current
      def change; end

      def self.version
        50_000_000_000_001
      end
    end

    expect { ActiveRecord::Migrator.new(:up, [ShardNotSetMigration]).migrate }.to(
      raise_error Sharder::Migrator::NoShardGroupSpecifiedError
    )

    expect(ActiveRecord::SchemaMigration.where(version: ShardNotSetMigration.version)).to_not exist
  end

  it "does not error when no database names are returned by the configurator for a migration" do
    class UnknownShardMigration < ActiveRecord::Migration::Current
      self.shard_group = :unknown_group

      def change
        add_column :club_index, :test, :integer
      end

      def self.version
        50_000_000_000_002
      end
    end

    ActiveRecord::Migrator.new(:up, [UnknownShardMigration]).migrate
    expect(ActiveRecord::SchemaMigration.where(version: UnknownShardMigration.version)).to exist

    ActiveRecord::Migrator.new(:down, [UnknownShardMigration]).migrate
    expect(ActiveRecord::SchemaMigration.where(version: UnknownShardMigration.version)).to_not exist
  end

  it "runs and rolls back a migration on for the default database" do
    class ValidMigration < ActiveRecord::Migration::Current
      self.shard_group = :default

      def change
        add_column :club_index, :tests, :integer
      end

      def self.version
        50_000_000_000_003
      end
    end

    ActiveRecord::Migrator.new(:up, [ValidMigration]).migrate
    expect(ActiveRecord::SchemaMigration.where(version: ValidMigration.version)).to exist
    ClubIndex.reset_column_information
    ClubIndex.create!(name: "Migration Test", tests: 2)

    ActiveRecord::Migrator.new(:down, [ValidMigration]).migrate
    expect(ActiveRecord::SchemaMigration.where(version: ValidMigration.version)).to_not exist
    ClubIndex.reset_column_information
    expect { ClubIndex.create!(name: "Migration Test", tests: 2) }.to(
      raise_error ActiveModel::UnknownAttributeError
    )
  end
end
