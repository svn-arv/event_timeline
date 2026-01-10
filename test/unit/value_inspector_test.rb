# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class ValueInspectorTest < TestCase
    test 'inspect returns string as-is when under limit' do
      result = ValueInspector.inspect('hello')
      assert_equal 'hello', result
    end

    test 'inspect truncates long strings' do
      configure_timeline { |c| c.max_string_length = 10 }

      long_string = 'a' * 20
      result = ValueInspector.inspect(long_string)

      assert_equal 13, result.length # 10 chars + "..."
      assert result.end_with?('...')
    end

    test 'inspect handles hashes under limit' do
      result = ValueInspector.inspect({ a: 1, b: 2 })
      assert_equal '{:a=>1, :b=>2}', result
    end

    test 'inspect truncates large hashes' do
      configure_timeline { |c| c.max_inspect_length = 20 }

      large_hash = (1..50).to_h { |i| ["key#{i}", "value#{i}"] }
      result = ValueInspector.inspect(large_hash)

      assert result.include?('Hash')
      assert result.include?('items')
    end

    test 'inspect handles arrays under limit' do
      result = ValueInspector.inspect([1, 2, 3])
      assert_equal '[1, 2, 3]', result
    end

    test 'inspect truncates large arrays' do
      configure_timeline { |c| c.max_inspect_length = 20 }

      large_array = (1..100).to_a
      result = ValueInspector.inspect(large_array)

      assert result.include?('Array')
      assert result.include?('items')
    end

    test 'inspect handles ActiveRecord new records' do
      session = Session.new(
        name: 'test',
        correlation_id: 'test-123',
        occurred_at: Time.current
      )

      result = ValueInspector.inspect(session)
      assert_includes result, 'Session'
      assert_includes result, 'new_record'
    end

    test 'inspect handles persisted ActiveRecord records' do
      session = Session.create!(
        name: 'test',
        correlation_id: 'test-123',
        occurred_at: Time.current
      )

      result = ValueInspector.inspect(session)
      assert_includes result, 'Session'
      assert_includes result, session.id.to_s
    end

    test 'inspect handles Class objects' do
      result = ValueInspector.inspect(String)
      assert_equal 'String', result
    end

    test 'inspect handles Module objects' do
      result = ValueInspector.inspect(Enumerable)
      assert_equal 'Enumerable', result
    end

    test 'inspect handles nil' do
      result = ValueInspector.inspect(nil)
      assert_equal 'nil', result
    end

    test 'inspect handles integers' do
      result = ValueInspector.inspect(42)
      assert_equal '42', result
    end

    test 'inspect_activerecord handles new records' do
      session = Session.new(name: 'test', correlation_id: 'x', occurred_at: Time.current)
      result = ValueInspector.inspect_activerecord(session)

      assert_includes result, 'Session'
      assert_includes result, 'new_record'
    end

    test 'activerecord_model? returns true for AR objects' do
      session = Session.new(name: 'test', correlation_id: 'x', occurred_at: Time.current)
      assert ValueInspector.activerecord_model?(session)
    end

    test 'activerecord_model? returns false for non-AR objects' do
      refute ValueInspector.activerecord_model?('string')
      refute ValueInspector.activerecord_model?(123)
      refute ValueInspector.activerecord_model?({})
    end
  end
end
