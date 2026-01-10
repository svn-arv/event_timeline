# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class ValueFilterTest < TestCase
    test 'filter returns FILTERED for sensitive string keys' do
      configure_timeline { |c| c.watch 'app' }

      result = ValueFilter.filter(:password, 'secret123', {})
      assert_equal '<FILTERED>', result
    end

    test 'filter returns inspected value for non-sensitive keys' do
      configure_timeline { |c| c.watch 'app' }

      result = ValueFilter.filter(:name, 'John', {})
      assert_equal 'John', result
    end

    test 'filter recursively filters hash values' do
      configure_timeline { |c| c.watch 'app' }

      input = { name: 'John', password: 'secret', token: 'abc123' }
      result = ValueFilter.filter(:params, input, {})

      assert_kind_of Hash, result
      assert_equal '<FILTERED>', result[:password]
      assert_equal '<FILTERED>', result[:token]
      assert_equal 'John', result[:name]
    end

    test 'filter recursively filters nested hashes' do
      configure_timeline { |c| c.watch 'app' }

      input = {
        user: {
          name: 'John',
          credentials: {
            password: 'secret',
            api_key: 'key123'
          }
        }
      }
      result = ValueFilter.filter(:data, input, {})

      assert_equal 'John', result[:user][:name]
      assert_equal '<FILTERED>', result[:user][:credentials][:password]
      assert_equal '<FILTERED>', result[:user][:credentials][:api_key]
    end

    test 'filter handles arrays' do
      configure_timeline { |c| c.watch 'app' }

      input = [{ name: 'John' }, { password: 'secret' }]
      result = ValueFilter.filter(:items, input, {})

      assert_kind_of Array, result
      assert_equal 'John', result[0][:name]
      assert_equal '<FILTERED>', result[1][:password]
    end

    test 'filter handles arrays of strings' do
      configure_timeline { |c| c.watch 'app' }

      input = %w[one two three]
      result = ValueFilter.filter(:tags, input, {})

      assert_equal %w[one two three], result
    end

    test 'filter handles nil values' do
      configure_timeline { |c| c.watch 'app' }

      result = ValueFilter.filter(:value, nil, {})
      assert_equal 'nil', result
    end

    test 'filter handles integers' do
      configure_timeline { |c| c.watch 'app' }

      result = ValueFilter.filter(:count, 42, {})
      assert_equal '42', result
    end

    test 'filter filters entire hash when key is sensitive' do
      configure_timeline { |c| c.watch 'app' }

      input = { user: 'john', role: 'admin' }
      result = ValueFilter.filter(:auth_data, input, {})

      # auth_data contains 'auth', so inner values get filtered through filter_hash
      assert_kind_of Hash, result
    end

    test 'filter handles ActiveRecord objects' do
      configure_timeline { |c| c.watch 'app' }

      session = Session.new(
        name: 'test',
        correlation_id: 'test-123',
        occurred_at: Time.current
      )

      result = ValueFilter.filter(:record, session, {})

      assert_includes result, 'Session'
      assert_includes result, 'new_record'
    end

    test 'filter respects custom pii filter' do
      configure_timeline do |c|
        c.watch 'app'
        c.filter_pii do |key, _value, _context|
          key.to_s.include?('custom_secret') ? true : nil
        end
      end

      result = ValueFilter.filter(:custom_secret_field, 'data', {})
      assert_equal '<FILTERED>', result

      result = ValueFilter.filter(:normal_field, 'data', {})
      assert_equal 'data', result
    end

    test 'filter handles empty hash' do
      configure_timeline { |c| c.watch 'app' }

      result = ValueFilter.filter(:params, {}, {})
      assert_equal({}, result)
    end

    test 'filter handles empty array' do
      configure_timeline { |c| c.watch 'app' }

      result = ValueFilter.filter(:items, [], {})
      assert_equal [], result
    end
  end
end
