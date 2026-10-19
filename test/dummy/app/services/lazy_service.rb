# frozen_string_literal: true

# Referenced by nothing else, so the tracker test is its first load.
class LazyService
  def ping
    :pong
  end
end
