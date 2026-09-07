# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class WikimediaApiTest < ActiveSupport::TestCase
  setup do
    WikimediaApi.reset_pause!
  end

  teardown do
    WikimediaApi.reset_pause!
  end

  test "parse_retry_after con secondi numerici interi e decimali" do
    assert_equal 5.0, WikimediaApi.parse_retry_after("5")
    assert_equal 120.0, WikimediaApi.parse_retry_after("120")
    assert_equal 12.5, WikimediaApi.parse_retry_after("12.5")
    assert_nil WikimediaApi.parse_retry_after("")
    assert_nil WikimediaApi.parse_retry_after(nil)
  end

  test "parse_retry_after con data HTTP futura" do
    future_time = Time.now + 60
    http_date = future_time.httpdate
    delay = WikimediaApi.parse_retry_after(http_date)

    assert delay >= 55 && delay <= 62
  end

  test "calculate_backoff utilizza retry_after se presente" do
    delay = WikimediaApi.calculate_backoff("15", 1)
    assert_equal 15.0, delay
  end

  test "calculate_backoff applica min_delay" do
    delay = WikimediaApi.calculate_backoff("1", 1, min_delay: 5.0)
    assert_equal 5.0, delay
  end

  test "set_pause e wait_if_paused coordinano la pausa" do
    WikimediaApi.set_pause(0.2)
    assert WikimediaApi.pause_until > Time.now

    start_time = Time.now
    WikimediaApi.wait_if_paused
    elapsed = Time.now - start_time

    assert elapsed >= 0.15
  end

  test "gestisce status 429 con retry-after simulato" do
    attempts = 0
    fake_response_429 = Struct.new(:code, :headers, :parsed_response, :body).new(
      429,
      { 'retry-after' => '1' },
      nil,
      'Too Many Requests'
    )
    fake_response_200 = Struct.new(:code, :headers, :parsed_response, :body).new(
      200,
      {},
      { 'query' => { 'searchinfo' => { 'totalhits' => 42 } } },
      '{"query":{"searchinfo":{"totalhits":42}}}'
    )

    HTTParty.stub(:send, ->(*args) {
      attempts += 1
      attempts == 1 ? fake_response_429 : fake_response_200
    }) do
      result = WikimediaApi.get("https://commons.wikimedia.org/w/api.php", query: { action: :query })
      assert_equal 42, result.dig('query', 'searchinfo', 'totalhits')
      assert_equal 2, attempts
    end
  end

  test "gestisce errore maxlag simulato" do
    attempts = 0
    fake_maxlag_response = Struct.new(:code, :headers, :parsed_response, :body).new(
      200,
      { 'retry-after' => '1' },
      { 'error' => { 'code' => 'maxlag', 'info' => 'Waiting for 10.0.0.1: 5 seconds lagged', 'lag' => 1 } },
      '{"error":{"code":"maxlag"}}'
    )
    fake_success_response = Struct.new(:code, :headers, :parsed_response, :body).new(
      200,
      {},
      { 'query' => { 'searchinfo' => { 'totalhits' => 10 } } },
      '{"query":{"searchinfo":{"totalhits":10}}}'
    )

    HTTParty.stub(:send, ->(*args) {
      attempts += 1
      attempts == 1 ? fake_maxlag_response : fake_success_response
    }) do
      result = WikimediaApi.get("https://commons.wikimedia.org/w/api.php", query: { action: :query })
      assert_equal 10, result.dig('query', 'searchinfo', 'totalhits')
      assert_equal 2, attempts
    end
  end
end
